/++
   tagsnatcher.d
   Author: Samuel Vargas

   This module is responsible for parsing the SDLang 
   file via recursive descent and placing desired Tags into
   several Array containers (aka ArrayList)
+/

module tagsnatcher;
import std.container, std.experimental.logger, global, sdlang;

class TagSnatcher {

   private {
      Array!Tag variables;
      Array!Tag languages;
      Array!Tag  programs;
   }

   this(Tag root) {
      recursiveDescend(root);
   }

   private {
      void recursiveDescend(Tag tag) {
         foreach (nested ; tag.all.tags) {
            switch (nested.namespace) {
               case "variables": variables.insertBack(nested); recursiveDescend(nested); break;
               case "language": languages.insertBack(nested); recursiveDescend(nested); break;
               case "program": programs.insertBack(nested); recursiveDescend(nested); break;
               case "": /+ ignore the default namespace +/ break;
               default: log(global.DEBUG, "unknown namespace: ", nested.namespace); break;
            } 
         }
      }
   }

   Array!Tag getVariables() { return variables; }
   Array!Tag getLanguages() { return languages; }
   Array!Tag getPrograms()  { return programs;  }
}
