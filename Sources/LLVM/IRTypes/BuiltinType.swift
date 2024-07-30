//
//  BuiltinType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/29/24.
//

import C_LLVM

public extension LLVM {
	struct BuiltinType: IRType {
		public typealias V = BuiltinValue
		public let name: String

		public init(name: String) {
			self.name = name
		}

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			fatalError("builtin types should not be referenced")
		}
	}
}
