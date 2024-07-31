//
//  FunctionType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	struct FunctionType: IRType {
		public typealias V = Function

		public var name: String
		public let returnType: any IRType
		public let parameterTypes: [any IRType]
		public let isVarArg: Bool
		public let captures: LLVM.CapturesStructType?

		public init(name: String, returnType: any IRType, parameterTypes: [any IRType], isVarArg: Bool, captures: LLVM.CapturesStructType?) {
			self.name = name
			self.returnType = returnType
			self.parameterTypes = parameterTypes
			self.isVarArg = isVarArg
			self.captures = captures
		}

		public func asReturnType(in context: LLVM.Context) -> LLVMTypeRef {
			LLVMPointerType(typeRef(in: context), 0)
		}

		public func emit(ref: LLVMValueRef) -> any LLVM.EmittedValue {
			EmittedFunctionValue(type: self, ref: ref)
		}

		public func typeRef(in context: Context = .global) -> LLVMTypeRef {
			var parameters: [LLVMTypeRef?] = parameterTypes.map { $0.typeRef(in: context) }

			if let captures, !captures.types.isEmpty {
				parameters.append(LLVMPointerType(captures.typeRef(in: context), 0))
			}

			return parameters.withUnsafeMutableBufferPointer {
				LLVMFunctionType(
					returnType.asReturnType(in: context),
					$0.baseAddress,
					UInt32($0.count),
					isVarArg ? 1 : 0
				)
			}
		}
	}
}
