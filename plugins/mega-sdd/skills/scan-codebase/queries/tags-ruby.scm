; Tree-sitter query for Ruby symbol extraction
; Adapted from Aider's tags.scm
; Captures: class/module/method definitions and references (.rb)

; Class definitions
(class
  name: (constant) @name.definition.class) @definition.class

; Module definitions
(module
  name: (constant) @name.definition.module) @definition.module

; Instance method definitions
(method
  name: (identifier) @name.definition.method) @definition.method

; Singleton (class-level) method definitions
(singleton_method
  name: (identifier) @name.definition.method) @definition.method

; Method calls (references)
(call
  method: (identifier) @name.reference.call) @reference.call

; Constant references (class usage)
(constant) @name.reference.constant
