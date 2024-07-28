//
//  VoidType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/27/24.
//

import C_LLVM

public extension LLVM {
	struct VoidValue: IRValue {
		public var type: LLVM.VoidType
	}

	struct VoidType: IRType {
		public typealias V = VoidValue

		public init() {}

		public func typeRef(in _: LLVM.Context) -> LLVMTypeRef {
			LLVMVoidType()
		}
	}
}
