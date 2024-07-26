//
//  StackValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//
import C_LLVM

public extension LLVM {
	struct StackValue<V: IRValue>: IRValue, IRValueRef, StoredPointer {
		public typealias T = V.T

		public let type: V.T
		public let value: V
		public let ref: LLVMValueRef
	}
}
