# Make-a-Lisp (1C:Enterprise Edition)

[![mal badge](https://img.shields.io/badge/mal-Make--a--Lisp-brightgreen.svg)](https://github.com/kanaka/mal)
[![1C:Enterprise](https://img.shields.io/badge/platform-1C:Enterprise-yellow.svg)](https://1c.ru/)

This repository contains an implementation of the **Lisp** programming language interpreter written in the **1C:Enterprise** scripting language (BSL - 1C:Enterprise script).

The project is developed as part of the large-scale educational initiative **[kanaka/mal (Make-a-Lisp)](https://github.com/kanaka/mal)**, where developers from all over the world build Lisp interpreters step-by-step in dozens of different programming languages.

## 🚀 About the Project

**Make-a-Lisp (mal)** is a step-by-step guide to writing a Lisp interpreter. The creation of the interpreter is divided into 11 sequential steps. Each step adds new functionality until a fully functional Lisp dialect is achieved, supporting macros, tail-call optimization, file I/O, and other advanced features.

This implementation is unique because it brings functional programming concepts and Lisp syntax into the 1C:Enterprise ecosystem.

## 🏗️ Repository Structure

The project code is provided as a configuration dump in XML format, compatible with the 1C Configurator or 1C:Enterprise Development Tools (EDT).

The main user interface is the `MakeALisp` data processor (`src/DataProcessors/MakeALisp`), which includes:
- **REPL (Read-Eval-Print Loop):** An interactive form (UI) for entering and executing Lisp code.
- **I/O Tools:** Loading and saving scripts to `.txt` files.
- **Test Templates:** Built-in templates containing tests for each development step.

## 🎯 Implementation Status (Steps)

The implementation is broken down into the following stages. Development progress:

- [ ] **Step 0:** REPL — Basic Read-Eval-Print Loop (simple echo response).
- [ ] **Step 1:** Read and Print — Parsing the string into an Abstract Syntax Tree (AST) and printing it back.
- [ ] **Step 2:** Eval — Basic evaluation of arithmetic and other simple expressions.
- [ ] **Step 3:** Environments — Adding environments (variable storage) and `let` / `def!` constructs.
- [ ] **Step 4:** If, Fn, Do — Core implementation: conditional statements, user-defined functions.
- [ ] **Step 5:** Tail Call Optimization (TCO) — Tail-call optimization to prevent stack overflow.
- [ ] **Step 6:** Files, Mutation, and Evil — File operations, state mutation, `eval`.
- [ ] **Step 7:** Quoting — Implementation of quoting (`quote`, `quasiquote`, `unquote`).
- [ ] **Step 8:** Macros — Adding support for macros (code as data, data as code).
- [ ] **Step 9:** Try / Catch — Exception handling.
- [ ] **Step A:** Mal — Self-hosting and final touches (host platform interoperability).

*The UI (Shell) and test templates (Test0 - TestA) are already integrated into the project.*

## 💻 How to Run

1. Clone the repository.
2. Load the source code (`src`) into an empty 1C:Enterprise configuration (via "Load configuration from files" in the Configurator, or import the project into EDT).
3. Update the database configuration and launch 1C in Enterprise mode.
4. Open the `MakeALisp` data processor (via the menu or file).
5. Select the current step, load tests, or write your own code in the interactive shell!

---
*Developed in pair programming with the AI assistant Antigravity (Google DeepMind).*
