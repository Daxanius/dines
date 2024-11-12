# Dines
The Google dinosaur game ported to the NES

## Building
Run build.bat, the result will be in the build folder

## Debugging
- Install the ca65 Macro Assembler Language Support addon for VSCode
- Install the Alchemy65 addon for VSCode
- Install the CC65 compiler
- Install MesenX

Each of the installed programs should be added to your path

Press F5 to debug

## Guidelines
- Write a comment for **every** line of assembly
- Use snake_case for processes, macros and variables
- Use camelCase for labels
- Use UPPER_CASE for "preprocessor" definitions
- Prefix macros with m_
- Write a comment above every process / macro stating its purpose and usage