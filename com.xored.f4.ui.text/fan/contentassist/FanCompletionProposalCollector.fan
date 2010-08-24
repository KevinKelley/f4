using [java] org.eclipse.dltk.core
using [java] org.eclipse.dltk.ui.text.completion
using [java] org.eclipse.swt.graphics
using [java] com.xored.fanide.core
using [java] fanx.interop
using [java] com.xored.f4.ui.text
using f4core

public class FanCompletionProposalCollector :
    ScriptCompletionProposalCollectorBridge {

  new make(ISourceModule module) : super(module) {
  }
      
  override ScriptCompletionProposal? createScriptCompletionProposal1(
      Str? completion, Int replaceStart, Int length, Image? image,
      Str? displayString, Int i, Bool isInDoc) {
    return FanCompletionProposal(completion, replaceStart, length,
        image, displayString, i, isInDoc)
  }

  override ScriptCompletionProposal? createOverrideCompletionProposal(
      IScriptProject? scriptProject, ISourceModule? compilationUnit,
      Str? name, Str?[]? paramTypes, Int start, Int length,
      Str? displayName, Str? completionProposal) {
    return FanOverrideCompletionProposal(scriptProject,
        compilationUnit, name, paramTypes, start, length, displayName,
        completionProposal)
  }

  override IScriptCompletionProposal? createMethodReferenceProposal(
    CompletionProposal? methodProposal) {
    LazyScriptCompletionProposal proposal := FanMethodCompletionProposal(
        methodProposal, getInvocationContext)
    return proposal;
  }

  override Str? getNatureId() {
    return FanNature.NATURE_ID
  }
}