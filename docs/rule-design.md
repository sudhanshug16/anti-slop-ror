# Rule design

The six cops deliberately inspect only syntax available to RuboCop's AST. They reject silent exception suppression, request-fed dynamic dispatch, request-fed external redirects, unbounded strong-parameter declarations, constructed SQL, and swallowed `ActiveRecord::StatementInvalid` inside a lexical transaction.

AST detection cannot prove that a variable aliases `params`, that a URL is safe after custom sanitization, that a SQL value is bound at runtime, or that a transaction reaches a database. It also cannot validate schema fields, nested route ownership, cache keys, job timing, protected benchmark files, or tests. Those failures need Rails behavior, schema/route inspection, Brakeman, or application tests. No cop autocorrects because each finding has business context.

The intentional boundaries are in the specs: literal names and SQL pass; `url_from(params[:next])` passes; mapped dispatch passes; explicit rescue values and re-raise pass; and `AllowedKeys` documents a reviewed schemaless strong-parameter key.
