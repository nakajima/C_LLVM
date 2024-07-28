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
		) -> Emitted {
			let operation = LLVM.BinaryOperation<Emitted>(op: op, lhs: lhs, rhs: rhs)
			let ref = LLVMBuildBinOp(builder, operation.op.toLLVM, lhs.ref, rhs.ref, "tmp")!

			switch lhs.type {
			case let value as IntType:
				return EmittedIntValue(type: value, ref: ref) as! Emitted
			default:
				fatalError()
			}
		}

		public func main(functionType: FunctionType) -> any EmittedValue {
			assert(functionType.name == "main", "trying to define \(functionType.name) as main!")

			let typeRef = functionType.typeRef(in: context)
			let functionRef = LLVMAddFunction(module.ref, functionType.name, typeRef)!
			let entry = LLVMAppendBasicBlock(functionRef, "entry")
			LLVMPositionBuilderAtEnd(builder, entry)
			return LLVM.EmittedFunctionValue(type: functionType, ref: functionRef)
		}

		// Emits a @declare for a function type
		public func add(functionType: FunctionType) -> EmittedType<FunctionType> {
			let typeRef = functionType.typeRef(in: context)
//			_ = LLVMAddFunction(module.ref, functionType.name, typeRef)
			return EmittedType(type: functionType, typeRef: builder)
		}

		public func define(_ functionType: FunctionType, parameterNames: [String], envStruct: CapturesStruct?, body: () -> Void) -> EmittedFunctionValue {
			let typeRef = functionType.typeRef(in: context)
			let functionRef = functionRef(for: functionType)

			let functionPointerRef = createFunctionPointer(
				name: functionType.name,
				functionType: functionType,
				functionRef: functionRef,
				envStruct: envStruct
			)

			// Get the current position we're at so we can go back there after the function is defined
			let originalBlock = LLVMGetInsertBlock(builder)
			let originalFunction = LLVMGetBasicBlockParent(originalBlock)

			// Create the entry block for the function
			let entryBlock = LLVMAppendBasicBlockInContext(context.ref, functionRef, "entry")

			for (i, name) in parameterNames.enumerated() {
				let paramRef = LLVMGetParam(functionRef, UInt32(i))
				LLVMSetValueName2(paramRef, name, name.count)
			}

			// Move the builder to our new entry block
			LLVMPositionBuilderAtEnd(builder, entryBlock)

			// Let the body block add some stuff
			body()

			// Get the new end of the original function
			if let originalFunction {
				let returnToBlock = LLVMGetLastBasicBlock(originalFunction)
				LLVMPositionBuilderAtEnd(builder, returnToBlock)
			}

			return EmittedFunctionValue(type: functionType, ref: functionPointerRef.ref)
		}

		public func call(_ fn: EmittedFunctionValue, with arguments: [any EmittedValue]) -> any EmittedValue {
			var args: [LLVMValueRef?] = arguments.map(\.ref)

			let functionPointerType = FunctionPointerType(functionType: fn.type)

			if fn.type.name.contains("fn_y") {}

			let functionRefPointer = LLVMBuildStructGEP2(
				builder,
				functionPointerType.typeRef(in: context),
				fn.ref,
				0,
				fn.type.name + "refPointer"
			)

			let functionRef = LLVMBuildLoad2(builder, LLVMPointerType(fn.type.typeRef(in: context), 0), functionRefPointer, fn.type.name)

			if let captures = fn.type.captures, !captures.types.isEmpty {
				let environmentRefPointer = LLVMBuildStructGEP2(
					builder,
					functionPointerType.typeRef(in: context),
					fn.ref,
					1,
					fn.type.name + "envPtr"
				)

				let environmentRef = LLVMBuildLoad2(builder, LLVMPointerType(captures.typeRef(in: context), 0), environmentRefPointer, "Env\(fn.type.name)")

				args.append(environmentRef)
			}

			let ref = args.withUnsafeMutableBufferPointer {
				LLVMBuildCall2(
					builder,
					fn.type.typeRef(in: context),
					functionRef,
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
			default:
				fatalError()
			}
		}

		public func call(_ fnPtr: LLVM.FunctionPointer, with arguments: [any EmittedValue]) -> any EmittedValue {
			guard let function = fnPtr.type as? FunctionType else {
				fatalError()
			}

			let loadedPtr = LLVMBuildLoad2(
				builder,
				LLVMTypeOf(fnPtr.ref),
				fnPtr.ref,
				function.name + "_call"
			)

			var args: [LLVMValueRef?] = arguments.map(\.ref)

			let ref = args.withUnsafeMutableBufferPointer {
				LLVMBuildCall2(
					builder,
					function.typeRef(in: context),
					loadedPtr,
					$0.baseAddress,
					UInt32($0.count),
					function.name
				)!
			}

			return switch function.returnType {
			case is IntType:
				EmittedIntValue(type: .i32, ref: ref)
			case let type as FunctionType:
				EmittedFunctionValue(type: type, ref: ref)
			case let typePointer as TypePointer<FunctionType>:
				EmittedFunctionValue(
					type: typePointer.type,
					ref: ref
				)
			default:
				fatalError()
			}
		}

		public func `struct`(type: StructType, values: [(String, any StoredPointer)]) -> any EmittedValue {
			let typeRef = type.typeRef(in: context)
			let pointer = malloca(type: type, name: "")

			for (i, value) in values.enumerated() {
				print("-> setting gep for \(value.0)")
				let field = LLVMBuildStructGEP2(builder, typeRef, pointer.ref, UInt32(i), "")
				LLVMBuildStore(builder, value.1.ref, field)
			}

			return pointer
		}

		public func malloca(type: any LLVM.IRType, name: String) -> any StoredPointer {
			let malloca = if let functionType = type as? FunctionType {
				{
					// Get the function
					let fn = LLVMGetNamedFunction(module.ref, functionType.name)!

					// Get a pointer type to the function
					let functionPointerType = LLVMPointerType(LLVMTypeOf(fn), 0)

					// Allocate the space for the function pointer
					let malloca = inEntry {
						LLVMBuildMalloc(builder, functionPointerType, name)!
					}

					return malloca
				}()
			} else {
				inEntry { LLVMBuildMalloc(builder, type.typeRef(in: context), name)! }
			}

			// Return the stack value
			switch type {
			case let type as LLVM.FunctionType:
				return HeapValue<LLVM.FunctionType>(type: type, ref: malloca)
			case let type as LLVM.IntType:
				return HeapValue<LLVM.IntType>(type: type, ref: malloca)
			case let type as LLVM.StructType:
				return HeapValue<LLVM.StructType>(type: type, ref: malloca)
			default:
				fatalError()
			}
		}

		public func alloca(type: any LLVM.IRType, name: String) -> any StoredPointer {
			let alloca = if let functionType = type as? FunctionType {
				{
					let fn = functionRef(for: functionType)

					// Get a pointer type to the function
					let functionPointerType = LLVMPointerType(LLVMTypeOf(fn), 0)

					// Allocate the space for the function pointer
					let alloca = inEntry {
						LLVMBuildAlloca(builder, functionPointerType, name)!
					}

					return alloca
				}()
			} else {
				inEntry { LLVMBuildAlloca(builder, type.typeRef(in: context), name)! }
			}

			// Return the stack value
			switch type {
			case let type as LLVM.FunctionType:
				return StackValue<LLVM.FunctionType>(type: type, ref: alloca)
			case let type as LLVM.IntType:
				return StackValue<LLVM.IntType>(type: type, ref: alloca)
			default:
				fatalError()
			}
		}

		public func store<Emitted: EmittedValue>(heapValue: Emitted, name: String = "") -> HeapValue<Emitted.T> {
			if let function = heapValue.type as? FunctionType {
				// Get the function
				let fn = LLVMGetNamedFunction(module.ref, function.name)!

				// Get a pointer type to the function
				let functionPointerType = LLVMPointerType(LLVMTypeOf(fn), 0)

				// Allocate the space for the function pointer
				let malloca = inEntry {
					LLVMBuildMalloc(builder, functionPointerType, name)!
				}

				// Actually store the function pointer into the spot
				let store = LLVMBuildStore(builder, fn, malloca)!

				// Return the stack value
				return HeapValue<Emitted.T>(type: heapValue.type, ref: malloca)
			} else {
				let malloca = inEntry { LLVMBuildAlloca(builder, heapValue.type.typeRef(in: context), name)! }
				let store = LLVMBuildStore(builder, heapValue.ref, malloca)!
				return HeapValue<Emitted.T>(type: heapValue.type, ref: malloca)
			}
		}

		public func store(_ value: any EmittedValue, to pointer: any StoredPointer) -> any StoredPointer {
			LLVMBuildStore(builder, value.ref, pointer.ref)
			return pointer
		}

		public func store(capture value: any EmittedValue, at index: Int, as envStructType: StructType) {
			let parameterCount = LLVMCountParams(currentFunction)

			// Get the env pointer
			let envParam = LLVMGetParam(currentFunction, parameterCount - 1)!

			// Load the env
			let env = LLVMBuildLoad2(builder, LLVMPointerType(envStructType.typeRef(in: context), 0), envParam, "envTmp")

			// Get the pointer to the captured value out of the env
			let ptr = LLVMBuildStructGEP2(
				builder,
				envStructType.typeRef(in: context),
				env,
				UInt32(index),
				"capture_\(index)Ptr_"
			)

			LLVMBuildStore(builder, value.ref, ptr)
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

		// When loading captured values, we need to go to the environment param passed
		// as the last argument.
		public func load(capture index: Int, envStructType: StructType) -> any EmittedValue {
			let paramCount = LLVMCountParams(currentFunction)

			// Get the env pointer
			let envParam = LLVMGetParam(currentFunction, paramCount - 1)!

			// Get the value out of the env
			let ptr = LLVMBuildStructGEP2(
				builder,
				envStructType.typeRef(in: context),
				envParam,
				UInt32(index),
				"capture_\(index)Ptr_"
			)

			let returnType = envStructType.types[index]
			let returningPtr = LLVMBuildLoad2(builder, LLVMPointerType(returnType.typeRef(in: context), 0), ptr, "capture_\(index)ReturningPtr_")!
			let returning = LLVMBuildLoad2(builder, returnType.typeRef(in: context), returningPtr, "capture_\(index)_")!
			return switch returnType {
			case let type as LLVM.IntType:
				EmittedIntValue(type: type, ref: returning)
			case let type as LLVM.FunctionType:
				EmittedFunctionValue(type: type, ref: returning)
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

		public func emit(constant: Constant<some IRValue, some Any>) -> any EmittedValue {
			let ref = constant.valueRef(in: context)

			switch constant.type {
			case let type as IntType:
				return EmittedIntValue(type: type, ref: ref)
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

		public func emit(return stackValue: StackValue<some IRValue>) -> any IRValue {
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

		public func emitVoidReturn() {
			LLVMBuildRetVoid(builder)
		}

		public func dump() {
			module.dump()
		}

		// MARK: Helpers

		private func createFunctionPointer(
			name: String,
			functionType: FunctionType,
			functionRef: LLVMValueRef,
			envStruct: CapturesStruct?
		) -> any StoredPointer {
			let types: [any IRType] = if let envStruct {
				[functionType, envStruct.type]
			} else {
				[functionType]
			}

			let structType = StructType(name: name, types: types)
			let structTypeRef = structType.typeRef(in: context)
			let pointer = malloca(type: structType, name: name)

			print("-> setting function ref for pointer: \(name)")
			let field = LLVMBuildStructGEP2(builder, structTypeRef, pointer.ref, UInt32(0), "")
			LLVMBuildStore(builder, functionRef, field)

			if let envStruct {
				print("-> setting environment ref for pointer: \(name)")
				let field = LLVMBuildStructGEP2(builder, structTypeRef, pointer.ref, UInt32(1), "")
				LLVMBuildStore(builder, envStruct.ref, field)
			}

			LLVMVerifyFunction(functionRef, LLVMPrintMessageAction)

			return pointer
		}

		private func functionRef(for functionType: FunctionType) -> LLVMValueRef {
			if functionType.name.contains("fn_y") {
				if let existing = LLVMGetNamedFunction(module.ref, functionType.name) {
					LLVMDumpValue(existing)
				} else {
					print("No existing function for \(functionType.name)")
				}
				// Get the function
			}
			if let fn = LLVMGetNamedFunction(module.ref, functionType.name) {
				return fn
			} else {
				return LLVMAddFunction(module.ref, functionType.name, functionType.typeRef(in: context))
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
