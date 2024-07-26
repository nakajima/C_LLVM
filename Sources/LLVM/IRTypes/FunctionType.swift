//
//  FunctionType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	public struct FunctionType: IRType {
		public typealias V = Function

		public let name: String
		public let returnType: any IRType
		public let parameterTypes: [any IRType]
		public let isVarArg: Bool

		public init(name: String, returnType: any IRType, parameterTypes: [any IRType], isVarArg: Bool) {
			self.name = name
			self.returnType = returnType
			self.parameterTypes = parameterTypes
			self.isVarArg = isVarArg
		}

		public func typeRef(in context: Context = .global) -> LLVMTypeRef {
			var parameters: [LLVMTypeRef?] = parameterTypes.map { $0.typeRef(in: context) }

			return parameters.withUnsafeMutableBufferPointer {
				LLVMFunctionType(
					returnType.typeRef(in: context),
					$0.baseAddress,
					UInt32($0.count),
					isVarArg ? 1 : 0
				)
			}
		}
	}
}
