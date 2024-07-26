//
//  StoredPointer.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	protocol StoredPointer: IRType, IRValue {
		associatedtype T: IRType

		var type: T { get }
		var ref: LLVMValueRef { get }
	}
}

public extension LLVM.StoredPointer {
	var isPointer: Bool {
		true
	}
}
