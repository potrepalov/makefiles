# makefiles
Makefile and auxiliaries for compiling MCU programm with libraries

Single instance of make programm process whole project tree and
call compilers for all updated source files.

Each source file may had unique compile options.
Compile options for a subtree or a file in subtree may set at any level
of project tree.

In diffrent folders may be source files with same name.

The presented system allows you to include a library of functions in the
form of the source texts and do not track changes in its composition:
in the main program it is sufficient to limit the inclusion of the processing
of the library files.mk file.  Possible further changes in the library
composition and compilation rules should be reflected
in the corresponding files.mk and will not cause
no changes in the compilation rules of the main program.  Exactly
to achieve this goal, this program compilation system was created.



Makefile и вспомогательные файлы компиляции программ с библиотеками для МК

Единственный вызов утилиты make обеспечивает обработку всего дерева
файлов проекта и компиляцию всех обновлённых исходных файлов.

Каждый файл с исходным текстом может компилироватся с уникальным
набором опций компилятора.  Опции компилятора могут устанавливаться
для каждого каталога/подкаталога проекта на любом уровне дерева
исходных файлов.

В разных каталогах могут находиться файлы с одинаковыми именами.

Представленная система позволяет включать библиотеку функций в виде исходных
текстов и не отслеживать изменения в её составе: в основной программе
достаточно ограничится включением обработки файла files.mk библиотеки.
Возможные дальнейшие изменения в составе библиотеки и правилах её компиляции
должны отражаться в соответствующем файле files.mk и не будут вызывать
никаких изменений в правилах компиляции основной программы.  Именно
для достижения этой цели была создана данная система компиляции программ.
