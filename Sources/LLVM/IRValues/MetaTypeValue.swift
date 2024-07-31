//
//  MetaTypeValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/30/24.
//

import C_LLVM

public extension LLVM {
	struct MetaType: EmittedValue {
		public var type: LLVM.StructType
		public var ref: LLVMValueRef

		public init(type: LLVM.StructType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
		}
	}
}
