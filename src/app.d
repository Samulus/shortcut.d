/++
    ___| |_ ___ ___| |_ ___ _ _| |_ 
   |_ -|   | . |  _|  _|  _| | |  _|
   |___|_|_|___|_| |_| |___|___|_|  

   Author: Samuel Vargas

   FUTURE:
      * Arbitrary placement of argv[0-n] in program lines using
        the sytnax |n..n|

   TODO: 
      * Detecting if a file exists in the path.
      * Standalone Programs
      * More robust error checking
+/

import std.stdio, std.file, std.algorithm,std.experimental.logger, 
       std.process, std.string, std.range, std.path,
       std.regex, std.container.array, sdlang;

class LanguageDB {

   private {
      Array!Tag languages;
      immutable OSType os;
      string[string] languageTable;
   }

   this(Array!Tag languages, immutable OSType os) {
      this.languages = languages;
      this.os = os;

      foreach (platformTag ; languages) {
         foreach (osTag ; platformTag.tags) {
            if (osTag.name == cast(string)os) {

               string path = osTag.values[0].get!string;

               if ("normalize" in osTag.attributes && 
                   osTag.attributes["normalize"][0].value.get!bool) {
                  path = buildNormalizedPath(path);
               }

               //assert(exists(path), format("[!] Language Not Found Assertation: Path: %s", path));

               languageTable[platformTag.name] = path;
            }
         }
      }

      log(format("Language Table:\n\t\t\t%s\n", languageTable));
   }

   string getLanguagePath(string language) {
      if (language !in languageTable) {
         throw new MissingLanguage(language);
      }

      return languageTable[language];
   }

   class MissingLanguage : Exception {
      this(string missingLanguage) {
         super(format("Language %s was used but doesn't actually exist", missingLanguage));
      }
   }
}

class ProgramDB {

   private {
      Array!Tag programs;
      immutable OSType os;
      string[string] programTable;
   }

   /++
      Populates the programTable using the parent language name + program name as the key
      and the program execution line as the value, i.e: Key:java.rsagen, Value: C:\rsagen.jar
   +/

   this(Array!Tag programs, immutable OSType os) {
      this.programs = programs;
      this.os = os;

      foreach (programTag ; programs) {

         /+ keep looking for programs if this program 
            doesn't have a tag with our current os's name 
         +/

         if (programTag.maybe.tags[os].empty) continue;

         string progPath = programTag.tags[os][0].values[0].get!string;

         /+ normalize if needed +/
         if ("normalize" in programTag.tags[os][0].attributes && 
                            programTag.tags[os][0].attributes["normalize"][0].value.get!bool) {
            progPath = buildNormalizedPath(progPath);
         }

         /+ append any extra values onto the programPath +/
         if (programTag.tags[os][0].values[0].length > 1) {
            foreach (val ; programTag.tags[os][0].values[1 .. $]) {
               progPath ~= " " ~ val.get!string;
            }
         }

         /+ add to programTable +/
         string name  = programTag.parent.name ~ "." ~ programTag.name;
         programTable[name] = progPath;
      }

      log(format("Program Table:\n\t\t\t%s\n", programTable));
   }

   /++
      Given a programName in the form xxx.program or just programName if there is only one
      it will attempt to get that corresponding formatted program command from the file

      Params:
         programName     = The name of the program you want to load, should be in the form
                           xxx.programName or just programName. If you pass in the
                           abbreviated form your string will be modified so that its
                           in the long form. i.e. myFancyBean becomes java.myFancyBean

         programCommand  = The resulting programCommand if found

         programLanguage = The language this program belonged to.
   +/

   void getProgram(ref string programName, ref string programCommand, ref string programLanguage) {

      string[] programsWithSameName;

      foreach (name, value ; programTable) {

         /+ if the user specifies an exact program using 
            "lang.program" syntax then grab it and exit +/
         if (name == programName) {
            log(app.DEBUG, format("Program %s, Value %s, was found in the Program Table\n", programName, value));
            programCommand  = value;
            programLanguage = name.split(".")[0];
            return;
         }

         /+ find a programName without a specified language +/
         if (name.endsWith(programName))  {
            log(app.DEBUG, format("Program %s, Value %s, was found in the Program Table\n", programName, value));
            programsWithSameName ~= name;
            programCommand  = value;
            programLanguage = name.split(".")[0];
         }
      }

      if (programsWithSameName.length == 0) {
         throw new MissingProgram(programName);
      }

      if (programsWithSameName.length > 1) {
         throw new AmbiguiousProgram(programName, programsWithSameName);
      }
   }

   class MissingProgramPath : Exception {
      this(string programName) {
         super(format("Found Program %s in config file but its missing a nested path tag", programName));
      }
   }

   class MissingProgram : Exception {
      this(string requested) {
         super(format("Program %s was requested but not found.", requested));
      }
   }

   class AmbiguiousProgram : Exception {
      this(string requested, string[] potentialPrograms) {
         super(format("Program %s was requested but this program could be any of the followng: %s\n" ~
                      "Please disambiguate by specifying your program in the form xxx.%s\n" ~
                      "Where xxx is a specific language",
                       requested, potentialPrograms, requested));
      }
   }

}

void usage(string progName, size_t argCount) {
   writefln("
    ___| |_ ___ ___| |_ ___ _ _| |_ 
   |_ -|   | . |  _|  _|  _| | |  _|
   |___|_|_|___|_| |_| |___|___|_|  

   Usage: %s progName arg1, arg2, argN..                          
   You supplied %d arguments but you need to supply >= 2

   Version: %d
   ", progName, argCount, app.VERSION);
}

int main(string[] args) {

   if (args.length < 2) {
      usage(args[0], args.length);
      return 0;
   }

   //app.DEBUG = args[0].baseName.startsWith("debug_");
   app.DEBUG = true;

   OSType os;

   version(linux) os = OSType.linux;
   version(OSX)   os = OSType.osx;
   version(Win32) os = OSType.win32;
   version(Win64) os = OSType.win64;

   try {
      auto root = parseFile(buildNormalizedPath(thisExePath.dirName, "shortcut.sdl"));
      auto snatcher = new TagSnatcher(root);

      auto variableDB = new VariableDB(snatcher.getVariables(), os);
      auto languageDB = new LanguageDB(snatcher.getLanguages(), os);
      auto programDB  = new ProgramDB(snatcher.getPrograms(), os);

      /+ load program +/
      string programCommand, programLanguage, languagePath;
      try { 
         programDB.getProgram(args[1], programCommand, programLanguage);
      } catch (ProgramDB.MissingProgram e) {
         stderr.writeln(e.msg);
         return -1;
      } catch (ProgramDB.AmbiguiousProgram e) {
         stderr.writeln(e.msg);
         return -1;
      } catch (Exception e) {
         stderr.writeln(e);
         return -1;
      }

      log(app.DEBUG, format("Language: %s, Program: %s, Command: %s", 
                             programLanguage, args[1], programCommand));

      try { 
         languagePath = languageDB.getLanguagePath(programLanguage);
      } catch (LanguageDB.MissingLanguage e) {
         stderr.writeln(e.msg);
         return -1;
      } catch (Exception e) {
         stderr.writeln(e);
         return -1;
      }

      log(app.DEBUG, format("Language: %s, Path: %s", programLanguage, languagePath));

      string finalCommand;

      try {
         finalCommand = 
            variableDB.generateCommand(languagePath, programCommand, args[1 .. $]);

      } catch (VariableDB.MissingVariable e) {
         stderr.writeln(e.msg);
         return -1;
      } catch (Exception e) {
         stderr.writeln(e);
         return -1;
      }

      log(app.DEBUG, "Executing Command: ", finalCommand);
      auto pid = spawnShell(finalCommand);
      wait(pid);

   } catch (SDLangParseException e) {
      stderr.writeln("Syntax Error:");
      stderr.writeln(e.msg);
      return -1;
   }

   return 0;
}
