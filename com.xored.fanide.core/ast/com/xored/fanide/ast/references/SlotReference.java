package com.xored.fanide.ast.references;

import org.eclipse.dltk.ast.ASTVisitor;
import org.eclipse.dltk.ast.references.SimpleReference;

public class SlotReference extends SimpleReference {

	public SlotReference(int start, int end, String name) {
		super(start, end, name);
	}

	@Override
	public void traverse(ASTVisitor visitor) throws Exception {
		if (visitor.visit(this)) {
			visitor.endvisit(this);
		}
	}

}