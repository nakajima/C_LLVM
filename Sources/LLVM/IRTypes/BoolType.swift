//
//  BoolType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	struct BoolType: IRType {
		public typealias V = BoolValue

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			IntType(width: 1).typeRef(in: context)
		}

		public func emit(ref: LLVMValueRef) -> any LLVM.EmittedValue {
			EmittedIntValue(type: .i1, ref: ref)
		}
	}
}
