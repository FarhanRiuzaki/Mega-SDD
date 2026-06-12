; Tree-sitter query for JavaScript symbol extraction
; Adapted from Aider's tags.scm
; Captures: function/class/method definitions and references (.js / .jsx / .mjs / .cjs)

; Class definitions
(class_declaration
  name: (identifier) @name.definition.class) @definition.class

; Function definitions
(function_declaration
  name: (identifier) @name.definition.function) @definition.function

; Arrow / function expressions bound to a const/let/var
(variable_declarator
  name: (identifier) @name.definition.function
  value: [(arrow_function) (function_expression)]) @definition.function

; Method definitions
(method_definition
  name: (property_identifier) @name.definition.method) @definition.method

; Object-literal function properties
(pair
  key: (property_identifier) @name.definition.function
  value: [(arrow_function) (function_expression)]) @definition.function

; Exported declarations (for public interface map)
(export_statement
  (function_declaration
    name: (identifier) @name.definition.exported.function))

(export_statement
  (class_declaration
    name: (identifier) @name.definition.exported.class))

; Function calls (references)
(call_expression
  function: (identifier) @name.reference.call) @reference.call

; Member expressions (method/property access)
(call_expression
  function: (member_expression
    property: (property_identifier) @name.reference.method)) @reference.method

; new-expression instantiations (references)
(new_expression
  constructor: (identifier) @name.reference.class) @reference.class
