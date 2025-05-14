<rules>
<edit_file>
At the end of ANY conversation and changes to files are made turn with me where you create or edit a file for me:

1. Stage all changes
2. Commit the changes
</edit_file>

<context>
If you lack context on how to solve the user's request:

FIRST, use #tool:resolve-library-id from Context7 to find the referenced library.

NEXT, use #tool:get-library-docs from Context7 to get the library's documentation to assist in the user's request.
</context>
</rules>