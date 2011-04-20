mixin IFanNamespace
{ 
  abstract IFanPod currPod()
  abstract Str[] podNames()
  abstract IFanPod? findPod(Str name)
  IFanType? findType(Str name) 
  { 
    if(name.isEmpty) return null
    if(name[-1] == '?') name = name[0..-2]

    //special handling for Lists and Maps
    IFanType? result := trySpecial(name)
    if(result != null) return result
    
    index := name.index("::")
    Str? pod := null
    if(index != null)
    {
      pod = name[0..<index]
      name = name[index+2..-1]
    }

    pods := pod == null ? podNames : [pod]
    result = pods.eachWhile { findPod(it)?.findType(name, false) }
    if(result == null)
    {
      //typeof.pod.log.warn("Unresolved type $name")
    }
    return result
  } 
  
  **
  ** Returns List or Map if applicable
  ** 
  private IFanType? trySpecial(Str name)
  {
    if(name.endsWith("[]"))
    {
      valueTypename := name[0..-3]
      valueType := findType(valueTypename)
      return findType("sys::List")?.parameterize(["sys::V" : valueType])
    }
    if(TypeUtil.isMapType(name))
    {
      Str cutName := name.startsWith("[") ? name[1..-2] : name
      bracesCount := 0
      for (i := 0; i < cutName.size; i++)
      {
        switch (cutName[i])
        {
          case '[': bracesCount++
          case ']': bracesCount--
          case ':':
          if (bracesCount == 0 && !TypeUtil.isQnamePos(cutName, i))
          {
            keyTypename := cutName[0..i - 1]
            valueTypename := cutName[i + 1..-1]
            keyType := findType(keyTypename)
            valueType := findType(valueTypename)
            return findType("sys::Map")?.parameterize(["sys::K" : keyType, "sys::V" : valueType])
          }
        }
      }
      // exceptional case, only if name is incorrect
      return findType("sys::Map")
    }
    if(name.startsWith("|")) { return findType("sys::Func") }
    return null
  }
}