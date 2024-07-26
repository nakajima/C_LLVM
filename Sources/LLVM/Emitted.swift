//
//  Emitted.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

public extension LLVM {
	public protocol Emitted {}
}

public extension LLVM.Emitted {
	func asValue<E: LLVM.EmittedValue>(of type: E.V.Type) -> E? {
		if let emitted = self as? E {
			return emitted
		}

		return nil
	}
}
