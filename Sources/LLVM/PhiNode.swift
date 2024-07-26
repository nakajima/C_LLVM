//
//  PhiNode.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	struct PhiNode<Value: IRValue>: EmittedValue {
		public var type: Value.T
		public let value: Value
		public var ref: LLVMValueRef
		
		public init(type: Value.T, value: Value, ref: LLVMValueRef) {
			self.type = type
			self.value = value
			self.ref = ref
		}
	}
}
