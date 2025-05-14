module main

import os
import term

fn main() {
	root := r'C:\VLang\Vcompiler\lab2\Project08-VMtestCodes'
	script := r'C:\VLang\Vcompiler\lab2\lab2test.v'

	if !os.exists(script) {
		eprintln('Missing script: ${script}')
		return
	}

	// Look inside all child folders for subfolders with .vm files
	for child in os.ls(root) or { panic('Failed to list root') } {
		child_path := os.join_path(root, child)
		if !os.is_dir(child_path) {
			continue
		}
		for grandchild in os.ls(child_path) or { continue } {
			gc_path := os.join_path(child_path, grandchild)
			if !os.is_dir(gc_path) {
				continue
			}
			vm_files := os.ls(gc_path) or { continue }
			if vm_files.any(it.ends_with('.vm')) {
				println(term.green('➡ Translating: ${gc_path}'))
				cmd := 'v run "${script}" "${gc_path.replace('\\', '\\\\')}"'
				result := os.execute(cmd)
				if result.exit_code == 0 {
					println(term.green('Success: ${grandchild}\n'))
				} else {
					eprintln(term.red('Failed: ${grandchild}'))
					eprintln(result.output)
				}
			}
		}
	}
}
