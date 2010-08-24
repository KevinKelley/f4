//
// Copyright (c) 2010 xored software, Inc.
// Licensed under Eclipse Public License version 1.0
//
// History:
//   Ivan Inozemtsev May 12, 2010 - Initial Contribution
//

using [java] org.eclipse.dltk.codeassist::ISelectionEngine
using [java] org.eclipse.dltk.codeassist::ISelectionRequestor
using [java] org.eclipse.dltk.compiler.env::IModuleSource
using [java] org.eclipse.dltk.core::IModelElement
using [java] org.eclipse.dltk.core::ISourceModule
using [java] org.eclipse.dltk.core::SourceParserUtil
using [java] org.eclipse.dltk.core.model::LocalVariable
using [java] java.util::Map as JMap

using f4parser
using f4model
**
**
**
class SelectionEngine : ISelectionEngine
{
  override Void setRequestor(ISelectionRequestor? requestor) {}

  override Void setOptions(JMap? map) {}
  
  override IModelElement?[]? select(IModuleSource? module, Int start, Int end) 
  { 
    DltkAst ast := SourceParserUtil.parse(module as ISourceModule, null)
    src = module.getSourceContents
    ns = FantomProjectManager.instance[module.getModelElement.getScriptProject.getProject].ns
    unit = ast.unit
    path := AstFinder.find(unit, start)
    node := path.last
    if(node == null) return IModelElement[,]
    if(node is ListType) return selectType(node->valType)
    else if(node is TypeDef) return selectTypeDef(node)
    else if(node is CType) return selectType(node)
    else if(node is SlotRef) return selectSlotRef(node)
    else if(node is SlotDef) return selectSlotDef(path)
    else if(node is MethodVarRef) return selectMethodVarRef(node)
    else if(node is MethodVar) return selectMethodVar(node as MethodVar)
    else if(node is Expr) return selectExpr(node)
    else if(ignored.any { node.typeof.fits(it) }) return IModelElement[,] //don't care about blocks
    else 
      typeof.pod.log.warn("Unknown node type $node.typeof")
    return IModelElement[,] 
  } 
  
  ** Node types which don't correspond to model elements
  private static const Type[] ignored := Type[
    Block#, 
    SLComment#, 
    ReturnStmt#
    ]
  
  private CUnit? unit
  private IFanNamespace? ns
  private Str? src
  private IModelElement[] selectType(CType? type)
  {
    me := type?.resolvedType?.me
    //TODO: Try to search
    return me == null ? [,] : [me] 
  }
  
  private IModelElement[] selectTypeDef(TypeDef def)
  {
    me := ns.currPod.findType(def.name.text, false)?.me
    return me == null ? [,] : [me] 
  }
  
  private IModelElement[] selectSlotRef(SlotRef ref) { [ref.modelSlot.me] }
  
  private IModelElement[] selectSlotDef(AstPath path)
  {
    DefNode node := path.last
    name := node.name.text
    TypeDef? type := path[-2] as TypeDef
    if(type == null)
    {
      echo(path[-2].typeof.name)
      return IModelElement[,]
    }
    me := ns.currPod.findType(type.name.text, false)?.slot(name, false)?.me
    return me == null ? [,] : [me]
  }
  
  private IModelElement[] selectMethodVarRef(MethodVarRef ref)
  {
    selectMethodVar(ref.def)
  }
  
  private IModelElement[] selectExpr(Expr node)
  {
    me := node.resolvedType?.me
    return me == null ? [,] : [me]
  }
  
  private IModelElement[] selectMethodVar(MethodVar def)
  {
    defNode := def as Node
    if(defNode == null)
    {
      typeof.pod.log.err("MethodVar $def.typeof is not node!")
      return IModelElement[,]
    }
    
    path := AstFinder.find(unit, defNode.start)
    methodName := (path.findLast(MethodDef#) as MethodDef)?.name?.text
    typeName := (path.findLast(TypeDef#) as TypeDef)?.name?.text
    if(methodName == null || typeName == null)
    {
      typeof.pod.log.err("MethodVar outside of method and type")
      return IModelElement[,]
    }
    
    me := ns.currPod.findType(typeName, false)?.method(methodName, false)?.me
    return me == null ? [,] : [LocalVariable(
        me, //parent
        def.name.text, //name
        defNode.start, defNode.end, //declaration location
        def.name.start, def.name.end, //name location
        methodVarType(def)
        )]
  }
  
  private Str? methodVarType(MethodVar def)
  {
    p := def as ParamDef
    if(p != null) return p.resolvedType?.name ?: ""
    l := def as LocalDef
    return l.resolvedType?.name ?: ""
  }
}
