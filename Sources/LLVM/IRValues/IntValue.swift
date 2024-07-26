//
//  IntValue.swift
//  C_LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	struct IntValue: IRValue {
		public let type: IntType
	}

	struct EmittedIntValue: EmittedValue {
		public let type: IntType
		public let value: IntValue
		public let ref: LLVMValueRef

		public init(type: IntType, value: IntValue, ref: LLVMValueRef) {
			self.type = type
			self.value = value
			self.ref = ref
		}
	}
}

