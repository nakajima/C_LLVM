//
//  Builder.swift
//  C_LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	class Builder {
		private let module: Module
		let builder: LLVMBuilderRef
		var context: Context { module.context }

		public init(module: Module) {
			self.builder = LLVMCreateBuilderInContext(module.context.ref)
			self.module = module
		}

		// Emits binary operation IR. LHS/RHS must be the same (which isn't tough because
		// we only support int at the moment).
		public func binaryOperation<Emitted: EmittedValue>(
			_ op: BinaryOperator,
			_ lhs: Emitted,
			_ rhs: Emitted
		) -> any EmittedValue {
			let operation = LLVM.BinaryOperation<Emitted>(op: op, lhs: lhs, rhs: rhs)
			let ref = LLVMBuildBinOp(builder, operation.op.toLLVM, lhs.ref, rhs.ref, "tmp")!

			switch lhs.value {
			case let value as IntValue:
				return EmittedIntValue(type: value.type, value: value, ref: ref)
			default:
				fatalError()
			}
		}

		// Emits a @declare for a function type
		public func add(functionType: FunctionType) -> EmittedType<FunctionType> {
			let typeRef = functionType.typeRef(in: context)
			_ = LLVMAddFunction(module.ref, functionType.name, typeRef)
			return EmittedType(type: functionType, typeRef: builder)
		}

		public func define(_ function: Function, body: () -> Void) -> EmittedFunctionValue {
			let typeRef = function.type.typeRef(in: context)
			let functionRef = LLVMAddFunction(module.ref, function.type.name, typeRef)!

			// Get the current position we're at so we can go back there after the function is defined
			let originalFunction: LLVMValueRef? = if let originalBlock = LLVMGetInsertBlock(builder) {
				LLVMGetBasicBlockParent(originalBlock)
			} else {
				nil // This means we're in main
			}

			// Create the entry block for the function
			let entryBlock = LLVMAppendBasicBlockInContext(context.ref, functionRef, "entry")

			// Move the builder to our new entry block
			LLVMPositionBuilderAtEnd(builder, entryBlock)

			// Let the body block add some stuff
			body()

			// Get the new end of the original function
			if let originalFunction {
				let returnToBlock = LLVMGetLastBasicBlock(originalFunction)
				LLVMPositionBuilderAtEnd(builder, returnToBlock)
			}

			if LLVMVerifyFunction(functionRef, LLVMPrintMessageAction) == 1 {
				fatalError("err")
			}

			return EmittedFunctionValue(type: function.type, value: function, ref: functionRef)
		}

		public func call(_ fnPtr: any StoredPointer, with arguments: [any EmittedValue]) -> any EmittedValue {
			guard let function = fnPtr.value as? Function else {
				fatalError()
			}

			let loadedPtr = LLVMBuildLoad2(
				builder,
				LLVMTypeOf(fnPtr.ref),
				fnPtr.ref,
				function.type.name + "_call"
			)

			var args: [LLVMValueRef?] = arguments.map(\.ref)

			let ref = args.withUnsafeMutableBufferPointer {
				LLVMBuildCall2(
					builder,
					function.type.typeRef(in: context),
					loadedPtr,
					$0.baseAddress,
					UInt32($0.count),
					function.type.name
				)!
			}

			return switch function.type.returnType {
			case is IntType:
				EmittedIntValue(type: .i32, value: IntValue(type: .i32), ref: ref)
			default:
				fatalError()
			}
		}

		// TODO: Move these to top of basic block
		public func store<Emitted: EmittedValue>(stackValue: Emitted, name: String = "") -> StackValue<Emitted.V> {
			if let function = stackValue.value as? Function {
				// Get the function
				let fn = LLVMGetNamedFunction(module.ref, function.type.name)!

				// Get a pointer type to the function
				let functionPointerType = LLVMPointerType(LLVMTypeOf(fn), 0)

				// Allocate the space for the function pointer
				let alloca = inEntry {
					LLVMBuildAlloca(builder, functionPointerType, name)!
				}

				// Actually store the function pointer into the spot
				let store = LLVMBuildStore(builder, fn, alloca)!

				// Return the stack value
				return StackValue<Emitted.V>(type: stackValue.type, value: stackValue.value, ref: alloca)
			} else {
				let alloca = inEntry { LLVMBuildAlloca(builder, stackValue.type.typeRef(in: context), name)! }
				let store = LLVMBuildStore(builder, stackValue.ref, alloca)!
				return StackValue<Emitted.V>(type: stackValue.type, value: stackValue.value, ref: alloca)
			}
		}

		public func load(parameter: Int) -> any EmittedValue {
			let ref = LLVMGetParam(currentFunction, UInt32(parameter))!
			return EmittedIntValue(type: .i32, value: IntValue(type: .i32), ref: ref)
		}

		public func load(pointer: any StoredPointer, name: String = "") -> any EmittedValue {
			let ref = LLVMBuildLoad2(builder, pointer.type.typeRef(in: context), pointer.ref, name)!

			switch pointer.type {
			case let type as IntType:
				return EmittedIntValue(type: type, value: IntValue(type: type), ref: ref)
			default:
				fatalError()
			}
		}

		public func emit<V: IRValue, Value>(constant: Constant<V, Value>) -> any EmittedValue {
			let ref = constant.valueRef(in: context)

			switch constant.type {
			case let type as IntType:
				return EmittedIntValue(type: type, value: IntValue(type: type), ref: ref)
			default:
				fatalError()
			}
		}

		public func emit(return value: any EmittedValue) -> any IRValue {
			let ref = LLVMBuildRet(
				builder,
				value.ref
			)!

			return value
		}

		public func emit(return value: RawValue) -> any IRValue {
			let ref = LLVMBuildRet(
				builder,
				value.ref
			)!

			return RawValue(ref: ref)
		}

		public func emit<V: IRValue>(return stackValue: StackValue<V>) -> any IRValue {
			let ref = LLVMBuildRet(
				builder,
				stackValue.ref
			)!

			switch stackValue.value {
			case let value as IntValue:
				return EmittedIntValue(type: value.type, value: value, ref: ref)
			default:
				fatalError("Not yet")
			}
		}

		private var currentFunction: LLVMValueRef {
			let currentBlock = LLVMGetInsertBlock(builder)
			return LLVMGetBasicBlockParent(currentBlock)
		}

		// Emits the block into the entry block of the current function
		func inEntry<T>(perform: () -> T) -> T {
			let currentBlock = LLVMGetInsertBlock(builder)
			let function = LLVMGetBasicBlockParent(currentBlock)
			let entryBlock = LLVMGetEntryBasicBlock(function)

			if let firstInstruction = LLVMGetFirstInstruction(entryBlock) {
				LLVMPositionBuilderBefore(builder, firstInstruction)
			} else {
				LLVMPositionBuilderAtEnd(builder, entryBlock)
			}

			let result = perform()

			LLVMPositionBuilderAtEnd(builder, currentBlock)
			return result
		}
	}
}
