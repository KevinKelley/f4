#! /usr/bin/env fan
//
// Copyright (c) 2014, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Dec 2014  Andy Frank  Creation
//

using build

**
** Build: domkit
**
class Build : BuildPod
{
  new make()
  {
    podName = "domkit"
    summary = "DOM Based UI Framework"
    meta     = ["org.name":     "Fantom",
                "org.uri":      "http://fantom.org/",
                "proj.name":    "Fantom Core",
                "proj.uri":     "http://fantom.org/",
                "license.name": "Academic Free License 3.0",
                "vcs.name":     "Mercurial",
                "vcs.uri":      "https://bitbucket.org/fantom/fan-1.0/"]
    depends = ["sys 1.0",
               "concurrent 1.0",
               "dom 1.0"]
    srcDirs = [`fan/`]
    resDirs = [`res/css/`]
  }

  @Target { help = "Compile to pod file and associated natives" }
  override Void compile()
  {
    compileCss
    super.compile
  }

  @Target { help = "Compile CSS" }
  virtual Void compileCss()
  {
    log.info("compileCss [$podName]")
    log.indent

    srcDir  := scriptDir + `fanCss/`
    resDir  := scriptDir + `res/css/`
    outFile := resDir + `${podName}.css`

    // clean up res/css/
    resDir.delete
    resDir.create
    log.info("CleanUp [$resDir]")

    // find css
    srcFiles := srcDir.listFiles.sort |a,b| { a.name.localeCompare(b.name) }
    log.info("FindCssFiles [$srcFiles.size files]")

    // merge css
    out := outFile.out
    srcFiles.each |f|
    {
      if (f.ext != "css") return
      f.eachLine |line|
      {
        trim := line.trim
        if (trim.isEmpty || trim.startsWith("//")) return
        out.printLine(line)
      }
      out.printLine("").flush
    }
    out.sync.close
    log.info("Merge [$outFile]")

    log.unindent
  }
}