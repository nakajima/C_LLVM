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
		var closureTypes: [String: LLVMTypeRef]
		let builder: LLVMBuilderRef
		var context: Context { module.context }

		public init(module: Module) {
			builder = LLVMCreateBuilderInContext(module.context.ref)
			self.module = module
			self.closureTypes = [:]
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

			switch lhs.type {
			case let value as IntType:
				return EmittedIntValue(type: value, ref: ref)
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

		public func define(
			_ function: Function,
			parameterNames: [String],
			environment: Function.Environment,
			body: () -> Void
		) -> EmittedFunctionValue {
			let typeRef = function.type.typeRef(in: context)
			let functionRef = LLVMAddFunction(module.ref, function.type.name, typeRef)!

			environment.functionRef = functionRef

			// Give the params actual names and save them in the environment
			for (i, name) in parameterNames.enumerated() {
				let paramRef = LLVMGetParam(functionRef, UInt32(i))!
				LLVMSetValueName2(paramRef, name, name.count)

				let parameterValue: any EmittedValue = switch function.type.parameterTypes[i] {
				case let type as IntType:
					EmittedIntValue(type: type, ref: paramRef)
				case let type as FunctionType:
					EmittedFunctionValue(type: type, ref: paramRef)
				default:
					fatalError()
				}

				environment.parameter(name, as: parameterValue)
			}

			// Get the current position we're at so we can go back there after the function is defined
			let originalBlock = LLVMGetInsertBlock(builder)
			let originalFunction: LLVMValueRef? = if let originalBlock {
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
			print("Ok we just emitted \(function.type.name)")

			// Get the new end of the original function
			if let originalFunction {
				let returnToBlock = LLVMGetLastBasicBlock(originalFunction)
				LLVMPositionBuilderAtEnd(builder, returnToBlock)
			}

			if let originalFunction {
				return inEntry(of: originalFunction) {
					// Store captures in a struct. TODO: It'd be nice to not do this if there are no captures.
					// ALSO TODO: Memory management???
					var closureTypes: [LLVMTypeRef?] = ([typeRef] + environment.captureList.map { $0.type.typeRef(in: context) }).map { LLVMPointerType($0, 0) }
					var closureValues: [LLVMValueRef?] = ([functionRef] + environment.captureList.map(\.ref))

					var closureStructType = LLVMStructCreateNamed(context.ref, "\(function.type.name)Closure")
					closureTypes.withUnsafeMutableBufferPointer {
						LLVMStructSetBody(
							closureStructType,
							$0.baseAddress,
							UInt32($0.count),
							LLVMBool(1)
						)
					}

					let closureLocation = LLVMBuildMalloc(builder, closureStructType, "\(function.type.name)ClosurePtr")!

					for i in 0 ..< closureValues.count {
						let ptr = LLVMBuildStructGEP2(
							builder,
							closureStructType,
							closureLocation,
							UInt32(i),
							"capture-\(i)"
						)

						LLVMBuildStore(builder, closureValues[i], ptr)
					}

					self.closureTypes[function.type.name] = closureStructType
					return EmittedFunctionValue(type: function.type, ref: closureLocation)
				}
			}

			// We don't emit a closure for main since it's weird.
			return EmittedFunctionValue(type: function.type, ref: functionRef)
		}

		public func call(
			_ fn: EmittedFunctionValue,
			with arguments: [any EmittedValue],
			in environment: Function.Environment
		) -> any EmittedValue {
			// Get the arguments passed to the function call
			var args: [LLVMValueRef?] = arguments.map(\.ref)

			var closureRef = fn.ref
			let loaded = LLVMBuildLoad2(
				builder,
				closureTypes[fn.type.name]!,
				closureRef,
				"\(fn.type.name)"
			)

			// Get the closure from the function

			let functionRef = withUnsafeMutablePointer(to: &closureRef) {
				LLVMBuildStructGEP2(
					builder,
					LLVMTypeOf(fn.ref),
					$0.pointee,
					0,
					fn.type.name
				)
			}

			let environmentRef = withUnsafeMutablePointer(to: &closureRef) {
				LLVMBuildStructGEP2(
					builder,
					LLVMTypeOf(fn.ref),
					$0.pointee,
					1,
					fn.type.name
				)
			}

			// Append captures to the argument list
			let ptrInt = LLVMBuildPtrToInt(
				builder,
				environmentRef,
				LLVMInt32Type(),
				"\(fn.type.name)Env"
			)

			args.append(ptrInt)

			let ref = args.withUnsafeMutableBufferPointer {
				LLVMBuildCall2(
					builder,
					fn.type.typeRef(in: context),
					fn.ref,
					$0.baseAddress,
					UInt32($0.count),
					fn.type.name
				)!
			}

			return switch fn.type.returnType {
			case is IntType:
				EmittedIntValue(type: .i32, ref: ref)
			case let type as FunctionType:
				EmittedFunctionValue(type: type, ref: ref)
			case let type as TypePointer<FunctionType>:
				EmittedFunctionValue(type: type.type, ref: ref)
			default:
				fatalError()
			}
		}

		public func call(
			_ fnPtr: any StoredPointer,
			with arguments: [any EmittedValue],
			in environment: Function.Environment
		) -> any EmittedValue {
			guard let function = fnPtr.type as? FunctionType else {
				fatalError()
			}

			let loadedFn = load(pointer: fnPtr, name: function.name) as! EmittedFunctionValue
			return call(loadedFn, with: arguments, in: environment)
//			let ref = args.withUnsafeMutableBufferPointer {
//				LLVMBuildCall2(
//					builder,
//					function.typeRef(in: context),
//					loadedPtr,
//					$0.baseAddress,
//					UInt32($0.count),
//					function.name
//				)!
//			}
//
//			return switch function.returnType {
//			case is IntType:
//				EmittedIntValue(type: .i32, ref: ref)
//			case let type as FunctionType:
//				EmittedFunctionValue(type: type, ref: ref)
//			case let typePointer as TypePointer<FunctionType>:
//				EmittedFunctionValue(
//					type: typePointer.type,
//					ref: ref
//				)
//			default:
//				fatalError()
//			}
		}

		public func capture(_ value: any EmittedValue, name: String, in functionRef: LLVMValueRef) -> any StoredPointer {
			inEntry(of: functionRef) { store(heapValue: value) }
		}

		public func capture(_ pointer: any StoredPointer, name: String, in functionRef: LLVMValueRef) -> any StoredPointer {
			let loaded = load(pointer: pointer)
			switch loaded {
			case let currentValue as EmittedIntValue:
				return inEntry(of: functionRef) { store(heapValue: currentValue, name: name) }
			case let currentValue as EmittedFunctionValue:
				return inEntry(of: functionRef) { store(heapValue: currentValue, name: name) }
			default:
				fatalError()
			}
		}

		public func store(heapValue: any EmittedValue, name: String = "") -> any StoredPointer {
			let ref = LLVMBuildMalloc(builder, heapValue.type.typeRef(in: context), name)!
			LLVMBuildStore(builder, heapValue.ref, ref)

			switch heapValue {
			case let value as EmittedIntValue:
				return HeapValue(type: value.type, ref: ref)
			case let value as EmittedFunctionValue:
				return HeapValue(type: value.type, ref: ref)
			default:
				fatalError()
			}
		}

		// TODO: Move these to top of basic block
		public func store<Emitted: EmittedValue>(stackValue: Emitted, name: String = "") -> StackValue<Emitted.T> {
			if let function = stackValue.type as? FunctionType {
				// Get the function
				let fn = LLVMGetNamedFunction(module.ref, function.name)!

				// Get a pointer type to the function
				let functionPointerType = LLVMPointerType(LLVMTypeOf(fn), 0)

				// Allocate the space for the function pointer
				let alloca = inEntry {
					LLVMBuildAlloca(builder, functionPointerType, name)!
				}

				// Actually store the function pointer into the spot
				let store = LLVMBuildStore(builder, fn, alloca)!

				// Return the stack value
				return StackValue<Emitted.T>(type: stackValue.type, ref: alloca)
			} else {
				let alloca = inEntry { LLVMBuildAlloca(builder, stackValue.type.typeRef(in: context), name)! }
				let store = LLVMBuildStore(builder, stackValue.ref, alloca)!
				return StackValue<Emitted.T>(type: stackValue.type, ref: alloca)
			}
		}

		public func load(parameter: Int) -> any EmittedValue {
			let ref = LLVMGetParam(currentFunction, UInt32(parameter))!
			return EmittedIntValue(type: .i32, ref: ref)
		}

		public func loadCapture(_ name: String, at index: Int, as type: any IRType) -> any EmittedValue {
			let offset = LLVMCountParams(currentFunction)
			let param = LLVMGetParam(currentFunction, offset - 1)!
			let ptr = LLVMBuildIntToPtr(builder, param, Struct, "\(name)envtmp")

			let ref = LLVMBuildStructGEP2(
				builder,
				LLVMPointerType(type.typeRef(in: context), 0),
				ptr,
				UInt32(index),
				name
			)!

			switch type {
			case let type as IntType:
				return EmittedIntValue(type: .i32, ref: ref)
			case let type as FunctionType:
				return EmittedFunctionValue(type: type, ref: ref)
			default:
				fatalError()
			}
		}

		public func load(pointer: any StoredPointer, name: String = "") -> any EmittedValue {
			switch pointer.type {
			case let type as IntType:
				let ref = LLVMBuildLoad2(builder, pointer.type.typeRef(in: context), pointer.ref, name)!
				return EmittedIntValue(type: type, ref: ref)
			case let type as FunctionType:
				// If it's a function we've stored a pointer to it (see store), so we need to change
				// the type to a pointer.
				let pointerType = LLVMPointerType(pointer.type.typeRef(in: context), 0)
				let ref = LLVMBuildLoad2(builder, pointerType, pointer.ref, name)!
				return EmittedFunctionValue(type: type, ref: ref)
			default:
				fatalError()
			}
		}

		public func emit<V: IRValue, Value>(constant: Constant<V, Value>) -> any EmittedValue {
			let ref = constant.valueRef(in: context)

			switch constant.type {
			case let type as IntType:
				return EmittedIntValue(type: type, ref: ref)
			default:
				fatalError()
			}
		}

		public func emitVoidReturn() {
			LLVMBuildRetVoid(builder)
		}

		public func emit(return value: any EmittedValue) -> any IRValue {
			if let value = value as? EmittedFunctionValue {
				let stored = store(heapValue: value)

				let ref = LLVMBuildRet(
					builder,
					stored.ref
				)

				return stored
			} else {
				let ref = LLVMBuildRet(
					builder,
					value.ref
				)!

				return value
			}
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

			switch stackValue.type {
			case let value as IntType:
				return EmittedIntValue(type: value, ref: ref)
			default:
				fatalError("Not yet")
			}
		}

		public func dump() {
			module.dump()
		}

		private var currentFunction: LLVMValueRef {
			let currentBlock = LLVMGetInsertBlock(builder)
			return LLVMGetBasicBlockParent(currentBlock)
		}

		func inEntry<T>(of function: LLVMValueRef, perform: () -> T) -> T {
			let currentBlock = LLVMGetInsertBlock(builder)
			let entryBlock = LLVMGetEntryBasicBlock(function)

//			if let firstInstruction = LLVMGetFirstInstruction(entryBlock) {
//				LLVMPositionBuilderBefore(builder, firstInstruction)
//			} else {
			LLVMPositionBuilderAtEnd(builder, entryBlock)
//			}

			let result = perform()

			LLVMPositionBuilderAtEnd(builder, currentBlock)
			return result
		}

		// Emits the block into the entry block of the current function
		func inEntry<T>(perform: () -> T) -> T {
			let currentBlock = LLVMGetInsertBlock(builder)
			let function = LLVMGetBasicBlockParent(currentBlock)
			let entryBlock = LLVMGetEntryBasicBlock(function)

			return inEntry(of: function!, perform: perform)
		}
	}
}
