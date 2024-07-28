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
		public let envStructType: LLVM.CapturesStructType?

		public init(name: String, returnType: any IRType, parameterTypes: [any IRType], isVarArg: Bool, envStructType: LLVM.CapturesStructType?) {
			self.name = name
			self.returnType = returnType
			self.parameterTypes = parameterTypes
			self.isVarArg = isVarArg
			self.envStructType = envStructType
		}

		public func asReturnType(in context: LLVM.Context) -> LLVMTypeRef {
			LLVMPointerType(typeRef(in: context), 0)
		}

		public func typeRef(in context: Context = .global) -> LLVMTypeRef {
			var parameters: [LLVMTypeRef?] = parameterTypes.map { $0.typeRef(in: context) }

			if let envStructType, !envStructType.types.isEmpty {
				parameters.append(envStructType.typeRef(in: context))
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

		public func typeRef(in context: Context = .global, captures: CapturesStruct) -> LLVMTypeRef {
			var parameters: [LLVMTypeRef?] = parameterTypes.map { $0.typeRef(in: context) }

			if !captures.captures.isEmpty {
				parameters.append(LLVMPointerType(captures.type.typeRef(in: context), 0))
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
