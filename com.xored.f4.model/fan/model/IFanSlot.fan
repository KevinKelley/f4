//
// Copyright (c) 2010 xored software, Inc.
// Licensed under Eclipse Public License version 1.0
//
// History:
//   Ivan Inozemtsev May 12, 2010 - Initial Contribution
//

const mixin IFanSlot : DltkModelElement
{
  **
  ** Field type for field and return type for method
  ** 
  abstract Str of()
  
//////////////////////////////////////////////////////////////////////////
// Naming
//////////////////////////////////////////////////////////////////////////

  **
  ** Parent type which defines this slot.
  **
  abstract Str parent()

  **
  ** Reference to parent type
  ** 
  abstract IFanType type()

  **
  ** Simple name of the slot such as "size".
  **
  abstract Str name()

  **
  ** Qualified name such as "sys:Str.size".
  **
  abstract Str qname()

  **
  ** Return true if this is an instance of Field.
  **
  abstract Bool isField()

  **
  ** Return true if this is an instance of Method.
  **
  abstract Bool isMethod()

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  **
  ** Return if slot is abstract (no implementation provided).
  **
  abstract Bool isAbstract()

  **
  ** Return if slot is constant and thread safe.  A constant field
  ** is explicitly marked with the const modifier and guaranteed
  ** to always reference the same immutable object for the life of
  ** the VM.  A const method is guaranteed to not capture any
  ** state from its thread, and is safe to execute on other threads.
  ** The compiler marks methods as const based on the following
  ** analysis:
  **   - static methods are always automatically const
  **   - instance methods are never const
  **   - closures which don't capture any variables from their
  **     scope are automatically const
  **   - partional apply methods which only capture const variables
  **     from their scope are automatically const
  **
  abstract Bool isConst()

  **
  ** Return if slot is constructor method.
  **
  abstract Bool isCtor()

  **
  ** Return if slot has internal protection scope.
  **
  abstract Bool isInternal()

  **
  ** Return if slot is native.
  **
  abstract Bool isNative()

  **
  ** Return if slot is an override (of parent's virtual method).
  **
  abstract Bool isOverride()

  **
  ** Return if slot has private protection scope.
  **
  abstract Bool isPrivate()

  **
  ** Return if slot has protected protection scope.
  **
  abstract Bool isProtected()

  **
  ** Return if slot has public protection scope.
  **
  abstract Bool isPublic()

  **
  ** Return if slot is static (class based, rather than instance).
  **
  abstract Bool isStatic()

  **
  ** Return if this slot was generated by the compiler.
  **
  abstract Bool isSynthetic()

  **
  ** Return if slot is virtual (may be overridden in subclasses).
  **
  abstract Bool isVirtual()

}