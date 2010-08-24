const mixin IFanPod
{
//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  **
  ** Simple name of the pod such as "sys".
  **
  abstract Str name()

//////////////////////////////////////////////////////////////////////////
// Types
//////////////////////////////////////////////////////////////////////////

  **
  ** List of the all defined types.
  **
  abstract Str[] typeNames()

  **
  ** Find a type by name.  If the type doesn't exist and checked
  ** is false then return null, otherwise throw UnknownTypeErr.
  **
  abstract IFanType? findType(Str name, Bool checked := true)
}