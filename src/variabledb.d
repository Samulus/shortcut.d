/++
   variabledb.d
   Author: Samuel Vargas

   This module is responsible for iterating through 
   an Array!Tag of variable tags
+/

import std.container.array, sdlang, std.path, std.file, finetype, global;

class VariableDB {

   private {
      Array!Tag variables;
      immutable OSType os;
      string[string] variableTable;
   }

   this(Array!Tag variables, immutable OSType os) {
      this.variables = variables;
      this.os = os;

      foreach (varTag ; variables) {
         foreach (tag ; varTag.tags) {
            string name  = varTag.name ~ "." ~ tag.name;
            string value = tag.values[0].get!string;

            if ("normalize" in tag.attributes && tag.attributes["normalize"][0].value.get!bool) {
               value = buildNormalizedPath(value);
            }

            if ("file" in tag.attributes && tag.attributes["file"][0].value.get!bool) {
               assert(exists(value), format("[!] File Not Found Assertation: Path: %s", value));
            }

            if ("eval" in tag.attributes && tag.attributes["eval"][0].value.get!bool) {
               value = executeShell(value).output;
               value = replaceAll(value, regex(r"\r\n|\n"), "");
            }

            bool onOurPlatform = tag.values[1 .. $].map!(v => v == cast(string)os).any ||
                                 tag.values.length == 1;
                                 
            if (onOurPlatform) 
               variableTable[name] = value;
         }
      }

      log(global.DEBUG, format("Variable Table:\n\t\t\t%s\n", variableTable));
   }

   string generateCommand(string languagePath, string formattedCommand, string[] args) {

      string[] split = split(formattedCommand);
      string result = languagePath ~ " ";

      foreach (word ; split) {

         /+ if a normal word is detected then add it to the
            result and move on +/
         if (!word.startsWith("$")) {
            result ~= word ~ " "; 
            continue;
         }

         /+ omit the dollar sign +/
         word = word[1 .. $];

         /+ if we can find this variable in the variable table
            then insert its value inplace +/

         bool found = false;
         foreach (key, value ; variableTable) {
            if (key == word) {
               result ~= value ~ " ";
               found = true;
            }
         }

         if (!found) {
            throw new MissingVariable(word, formattedCommand);
         }
      }

      foreach (immutable string arg ; args) {
         result ~= " " ~ arg;
      }

      return result;
   }

   class MissingVariable : Exception {
      this(string missingVar, string executionCommand) {
         super(format("Variable %s was used in the line %s but was never loaded into the VariableTable", 
                       missingVar, executionCommand));
      }
   }

}
