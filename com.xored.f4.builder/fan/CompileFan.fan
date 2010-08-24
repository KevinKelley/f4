//
// Copyright (c) 2009-2010 xored software, Inc.
// Licensed under Eclipse Public License version 1.0
//
// History:
//   Andrey Platov Oct 12, 2009 - Initial Contribution
//   Ivan Inozemtsev Apr 09, 2010 - Reanimation
//
using compiler
using f4core

using [java]java.util::List as JList 
using [java]java.util::Set as JSet
using [java]org.eclipse.core.runtime
using [java]org.eclipse.core.resources::IFile
using [java]org.eclipse.core.resources::IResource
using [java]org.eclipse.core.resources::IProject
using [java]org.eclipse.core.resources::ResourcesPlugin
using [java]org.eclipse.dltk.compiler.problem::DefaultProblem
using [java]org.eclipse.dltk.compiler.problem::ProblemSeverities
using [java]org.eclipse.dltk.core
using [java]org.eclipse.dltk.core.builder
using [java]org.eclipse.dltk.core.builder::IScriptBuilder$DependencyResponse as DependencyResponse
using [java]org.eclipse.core.filesystem::URIUtil
using [java]org.eclipse.jdt.core::JavaCore
using [java]org.eclipse.jdt.launching::JavaRuntime
using [java]org.eclipse.jdt.launching::IRuntimeClasspathEntry
using [java]org.eclipse.dltk.launching::ScriptRuntime
using [java]org.eclipse.dltk.launching::LibraryLocation
using [java]com.xored.fanide.core.utils::FanProjectUtils
**************************************************************************
** CompileFan
**************************************************************************
**
** IScriptBuilder implementationt to build Fantom projects
** 
class CompileFan : IScriptBuilder
{
  //////////////////////////////////////////////////////////////////////////
  // Interface methods
  //////////////////////////////////////////////////////////////////////////
  
  **
  ** Initialize before a build session
  ** 
  ** @param project
  **
  override Void initialize(IScriptProject? project)
  {
    //do nothing
  }

  **
  ** Called for each resource required to build. Only resources with specified
  ** project nature are here.
  ** 
  override IStatus? buildResources(IScriptProject? project, JList? resList,
      IProgressMonitor? monitor, Int status)
  {
    if(!building)
    {
      fp := fantomProject(project)
      if(buildRequired(fp, resList.toArray)) buildPod(fp)
    }
    return Status(IStatus.OK, pluginId, "OK")
  }
  
  
  **
  ** Return all dependencies for selected resource. Should also return all
  ** dependencies of returned elements.
  ** 
  ** For example if c depends on b and b depends on a, and we ask for
  ** dependencies or a, then b and c should be returned.
  ** 
  ** Resources should be checked for type. Because different kind of resource
  ** could be here.
  ** 
  ** @param buildType
  **            build type {@link #FULL_BUILD} or {@link #INCREMENTAL_BUILD}
  ** @param localElements
  **            changed source modules
  ** @param externalElements
  **            newly added external source modules
  ** @param oldExternalFolders
  **            old external fragments
  ** @param externalFolders
  **            new external fragments
  ** @return <code>null</code> if there are no dependencies found,
  **         {@link DependencyResponse#FULL_LOCAL_BUILD} to promote to the
  **         full build, or the result of
  **         {@link DependencyResponse#create(Set)}
  **
  override DependencyResponse? getDependencies(IScriptProject? project, Int buildType,
      JSet? localElements, JSet? externalElements, JSet? oldExternalFolders,
      JSet? externalFolders)  { return null }

  private FantomProject[] allDependents(FantomProject project, FantomProject[] allProjects)
  {
    result := FantomProject[,]
    dependents(project, allProjects).each |p|
    {
      result.add(p)
      result.addAll(allDependents(p, allProjects))
    }
    return result.unique
  }
  
  private FantomProject[] dependents(FantomProject project, FantomProject[] allProjects)
  {
    allProjects.findAll |FantomProject candidate ->Bool| 
    { 
      candidate.rawDepends.any |Depend d -> Bool| 
      {
        d.name == project.podName
      }
    }
  }
  **
  ** @see IncrementalProjectBuilder
  ** 
  override Void clean(IScriptProject? project, IProgressMonitor? monitor)
  {
    clearMarkers(project.getProject)
  } 

  **
  ** Reset after a build session
  ** 
  override Void endBuild(IScriptProject? project, IProgressMonitor? monitor) 
  {
    reporters.vals.each { it.flush }
    reporters.clear
    building = false
  }
  
  static const Str pluginId := "com.xored.f4.builder"
  **
  ** Called for each resource required to build. Only resources with specified
  ** project nature are here.
  ** 
  override IStatus? buildModelElements(IScriptProject? project, JList? elements,
      IProgressMonitor? monitor, Int status)
  {
    allProjects := FantomProjectManager.instance.listProjects
    fp := fantomProject(project)
    projectsToBuild := [fp].addAll(allDependents(fp, allProjects))
    projectsToBuild.sort |FantomProject a, FantomProject b -> Int|
    {
      //b depends on a
      if(allDependents(a,allProjects).contains(b)) return -1
      //a depends on b
      else if(allDependents(b,allProjects).contains(a)) return 1
      return 0
    }.each 
    { 
      buildPod(it) 
    }
    return Status(IStatus.OK, pluginId, "OK")
  }
  
  private FantomProject[] projectsFromElements(ISourceModule[] modules)
  {
    modules.map { fantomProject(it.getScriptProject) }.unique
  }
  
  private Void buildPod(FantomProject fp)
  {
    building = true
    clearMarkers(fp.project)
    if(fp.hasErrs)
    {
      reportProjectErrs(fp)
      return
    }
    
    if(!fp.isInterpreterSet)
    {
      reportInterpreterErrors(fp)
      return
    }
    
    buf := StrBuf()
    input := CompilerInput.make
    input.log         = CompilerLog(buf.out)
    input.podName     = fp.podName
    input.version     = fp.version
    input.ns          = F4Namespace(getAllPods(fp), fp.classpath)
    input.depends     = fp.rawDepends.dup
    input.includeDoc  = true
    input.summary     = fp.summary
    input.mode        = CompilerInputMode.file
    input.baseDir     = fp.baseDir
    input.srcDirs     = fp.srcDirs
    input.resDirs     = fp.resDirs
    input.index       = fp.index
    input.outDir      = fp.outDir
    input.output      = CompilerOutputMode.podFile
    input.jsDirs      = fp.jsDirs

    compile(input).each |err| 
    {
      reportErr(err, fp.project) 
    }
    refreshPod(fp)
  }
  
  private static [Str:File] getAllPods(FantomProject fp)
  {
    result :=  [:]
    
    //add interpreter libraries
    libLocs := ScriptRuntime.getLibraryLocations(fp.getInterpreterInstall) as LibraryLocation[]
    libLocs.each 
    {
      file := PathUtil.resolveLocalPath(it.getLibraryPath())
      result[file.basename] = file
    }
    
    //add workspace pods
    FantomProjectManager.instance.listProjects.each |FantomProject p|
    {
      result[fp.podName] = (fp.outDir.uri + `${fp.podName}.pod`).toFile
    }
    
    return result
  }
  
  private Void refreshPod(FantomProject project)
  {
    if(project.rawOutDir == null || project.rawOutDir.isAbs) return
    path := Path("${project.rawOutDir.toStr}${project.podName}.pod")
    podFile := project.project.getFile(path) 
    try
    {
      podFile.refreshLocal(IResource.DEPTH_ZERO, null)
    } catch(Err e) 
    { 
      //do nothing
      //TODO: report warning
    }
  }
  
  private CompilerErr[] compile(CompilerInput input)
  {
    caughtErrs := CompilerErr[,]
    compiler := Compiler(input)
    try { compiler.compile } 
    catch(CompilerErr e) 
    {
      caughtErrs.add(e) 
    }
    catch(Err e)
    {
      e.trace
    }
    return [compiler.errs, compiler.warns, caughtErrs].flatten.unique
  }

  //////////////////////////////////////////////////////////////////////////
  // Helper methods
  //////////////////////////////////////////////////////////////////////////
  private FantomProject fantomProject(IScriptProject project)
  {
    FantomProjectManager.instance[project.getProject]
  }
  private Bool buildRequired(FantomProject project, IResource[] resources)
  {
    resources.any |res|
    {
      res.getName == Manifest.filename || 
      project.resDirs.any |rd|
      {
        resDir := rd.path.join("/")
        resParent := res.getParent.getProjectRelativePath.toStr
        return resDir == resParent
      }
    }
  }
  //////////////////////////////////////////////////////////////////////////
  // Report errors methods
  //////////////////////////////////////////////////////////////////////////
  private IResource resource(IProject project, Str? file)
  {
    if (file != null) 
    {
      IFile[] files := ResourcesPlugin.getWorkspace.getRoot.
        findFilesForLocationURI(URIUtil.toURI(Path(file).makeAbsolute))
      if (!files.isEmpty) return files.first
    }
    return project
  }
  
  private Str:ProblemReporter reporters := [Str:ProblemReporter][:]
  
  private Void reportErrs(ProblemReporter r, ProjectErr[] errs)
  {
    l := r.resource.getLocation.toString
    errs.each 
    {
      r.reportProblem(
        DefaultProblem(
            l,
            it.msg,
            0, 
            Str[,],
            ProblemSeverities.Error,
            -1,
            -1,
            it.line,
            -1
          )
        )
    }
  }
  private Void reportProjectErrs(FantomProject project)
  {
    p := project.project
    reportErrs(reporters.getOrAdd(p.getLocationURI.toString) |->Obj| { ProblemReporter(p) }, project.projectErrs)
    f := project.project.getFile(Manifest.filename)
    reportErrs(reporters.getOrAdd(f.getLocationURI.toString) |->Obj| { ProblemReporter(f) }, project.buildfanErrs)
    
  }
  
  private Void reportInterpreterErrors(FantomProject project)
  {
    err := ProjectErr("Interpreter is not configured")
    p := project.project
    reportErrs(reporters.getOrAdd(p.getLocationURI.toString) |->Obj| { ProblemReporter(p) }, [err])
  }
  
  private Void reportErr(CompilerErr err, IProject project)
  {
    resource := resource(project, err.file)
    reporter := reporters.getOrAdd(resource.getLocationURI.toString) |->Obj| { ProblemReporter(resource) }
    reporter.reportProblem(
      DefaultProblem(
        resource.getLocation.toString, 
        err.msg, 
        0, //id (don't know what this means)
        Str[,], //arguments (don't know what this means)
        err.isWarn || err.msg == "No fan source files found"? ProblemSeverities.Warning : ProblemSeverities.Error, //severity
        -1, //start position
        -1, //end position
        err.line ?: 0,
        err.col ?: 0
        )
      )
  }
  
  private Void clearMarkers(IProject project)
  {
    project.deleteMarkers(F4Consts.buildProblem, true, IResource.DEPTH_INFINITE)
  }
  
  private Bool building := false
}
