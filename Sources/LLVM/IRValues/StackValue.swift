//
//  StackValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//
import C_LLVM

public extension LLVM {
	struct StackValue<T: IRType>: IRValue, IRValueRef, StoredPointer {
		public typealias V = T.V

		public let type: T
		public let ref: LLVMValueRef

		public func typeRef(in _: LLVM.Context) -> LLVMTypeRef {
			ref
		}
	}
}
