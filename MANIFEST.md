# SHOUTECH ERP V9 - System Manifest

## 1. Project Identity

**Name:** SHOUTECH ERP V9  
**Type:** Windows Desktop ERP System  
**Target Platform:** Windows x64  
**Architecture:** Modular Desktop ERP  
**Primary Language:** C# / .NET  
**Native Security Engine:** C++20  
**Database:** SQLite-based local architecture  
**Reporting:** FastReport  
**AI Engine:** Local Python/FastAPI + ONNX  
**Deployment Model:** Offline-first / Local installation  

---

## 2. Project Goal

SHOUTECH ERP V9 is designed to be a professional local ERP system for small and medium businesses, with a focus on:

- Accounting
- Inventory
- Sales and purchases
- Financial years
- Multi-company support
- Reporting
- Backup and restore
- Licensing and activation
- Local AI assistance
- Optional plugins

The system is designed primarily for Arabic business environments and Windows-based deployments.

---

## 3. Core Design Principles

1. **Windows-first**
   - The system targets Windows x64 only in the current version.

2. **Offline-first**
   - The core ERP must work without internet access.

3. **Modular architecture**
   - Core modules are separated into independent projects and DLLs.

4. **Native security boundary**
   - Security-sensitive operations are handled by the native C++ security engine.

5. **Database isolation**
   - Company and financial-year data must be organized clearly and safely.

6. **No direct database chaos**
   - Business logic must not be scattered inside UI code.

7. **Auditability**
   - Sensitive actions must be logged through audit mechanisms.

8. **Extensibility**
   - Optional modules can be added through plugins.

---

## 4. Final Project Structure

```text
shoutech_erp_v9/
├── bin/
├── bld/
├── cfg/
├── cod/
├── dba/
├── doc/
├── ext/
├── git/
├── int/
├── lib/
├── log/
├── rpt/
├── sec/
├── svc/
├── tls/
├── .gitattributes
├── .gitignore
├── bld.bat
├── LICENSE
├── man.md
├── read.md
├── ShouTech.sln
└── sum.md