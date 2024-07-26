//
//  Pointer.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	protocol StoredPointer: IRValue {
		associatedtype V: IRValue

		var type: V.T { get }
		var value: V { get }
		var ref: LLVMValueRef { get }
	}
}

public extension LLVM.StoredPointer {
	var isPointer: Bool {
		true
	}
}

