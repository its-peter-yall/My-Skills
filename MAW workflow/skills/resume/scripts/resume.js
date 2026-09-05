#!/usr/bin/env node
/**
 * Workflow Resume Helper for MAW and MAW-lite
 * Discovers and validates resumable workflows containing state.md in the docs/ directory.
 * Pure Node.js standard library - zero external npm dependencies.
 */

const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    objective: null,
    docsDir: null,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--objective' || arg === '-o') {
      options.objective = args[++i];
    } else if (arg.startsWith('--objective=')) {
      options.objective = arg.split('=')[1];
    } else if (arg === '--docs-dir' || arg === '-d') {
      options.docsDir = args[++i];
    } else if (arg.startsWith('--docs-dir=')) {
      options.docsDir = arg.split('=')[1];
    }
  }

  return options;
}

function toPosixPath(filepath) {
  return filepath.replace(/\\/g, '/');
}

function parseStateMetadata(stateFilePath) {
  const parentDirName = path.basename(path.dirname(stateFilePath));
  const metadata = {
    objective: parentDirName,
    workflow: 'unknown',
    title: parentDirName,
    total_tasks: 0,
    completed_tasks: 0,
    in_progress_tasks: 0,
    pending_tasks: 0,
    last_updated: null,
  };

  let content = '';
  try {
    content = fs.readFileSync(stateFilePath, 'utf8');
  } catch (err) {
    metadata.error = `Failed to read file: ${err.message}`;
    return metadata;
  }

  // 1. Parse YAML frontmatter if present
  const fmMatch = content.match(/^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n/);
  if (fmMatch) {
    const lines = fmMatch[1].split(/\r?\n/);
    for (const line of lines) {
      if (line.includes(':')) {
        const parts = line.split(':');
        const key = parts[0].trim().toLowerCase();
        const val = parts.slice(1).join(':').trim().replace(/^['"]|['"]$/g, '');
        if (key === 'workflow') {
          metadata.workflow = val.toLowerCase();
        } else if (key === 'objective') {
          metadata.objective = val;
        }
      }
    }
  }

  // 2. Fallback regex for workflow header if not in frontmatter
  if (metadata.workflow === 'unknown') {
    const wfMatch = content.match(/\b[Ww]orkflow\s*[:=]\s*([a-zA-Z0-9_-]+)/);
    if (wfMatch) {
      metadata.workflow = wfMatch[1].toLowerCase();
    }
  }

  // 3. Detect workflow from file structure / content hints if still unknown
  if (metadata.workflow === 'unknown') {
    if (content.includes('Phase Hierarchy') || content.toLowerCase().includes('maw-full')) {
      metadata.workflow = 'maw-full';
    } else if (content.includes('Dependency Matrix') || content.toLowerCase().includes('pipelined')) {
      metadata.workflow = 'maw';
    }
  }

  // 4. Handle legacy workflow mappings
  if (metadata.workflow === 'maw-lite') {
    metadata.workflow = 'maw';
  } else if (metadata.workflow === 'maw' && (content.includes('Phase Hierarchy') || content.includes('phase-1'))) {
    metadata.workflow = 'maw-full';
  }

  // 4. Count progress checkboxes
  const completed = (content.match(/-\s*\[x\]/gi) || []).length;
  const inProgress = (content.match(/-\s*\[#\]/g) || []).length;
  const pending = (content.match(/-\s*\[ \]/g) || []).length;

  metadata.completed_tasks = completed;
  metadata.in_progress_tasks = inProgress;
  metadata.pending_tasks = pending;
  metadata.total_tasks = completed + inProgress + pending;

  if (metadata.total_tasks > 0) {
    metadata.progress_percent = Math.floor((completed / metadata.total_tasks) * 100);
  } else {
    metadata.progress_percent = 0;
  }

  return metadata;
}

function scanDocsDirectory(docsDir) {
  const resumableList = [];
  if (!fs.existsSync(docsDir) || !fs.statSync(docsDir).isDirectory()) {
    return resumableList;
  }

  const entries = fs.readdirSync(docsDir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    if (entry.isDirectory()) {
      const stateFile = path.join(docsDir, entry.name, 'state.md');
      if (fs.existsSync(stateFile) && fs.statSync(stateFile).isFile()) {
        const meta = parseStateMetadata(stateFile);
        meta.path = toPosixPath(stateFile);
        resumableList.push(meta);
      }
    }
  }

  return resumableList;
}

function main() {
  const options = parseArgs();
  const cwd = process.cwd();
  const docsDir = options.docsDir ? path.resolve(options.docsDir) : path.join(cwd, 'docs');
  const posixDocsDir = toPosixPath(docsDir);
  const posixCwd = toPosixPath(cwd);

  // Check if docs/ directory exists
  if (!fs.existsSync(docsDir) || !fs.statSync(docsDir).isDirectory()) {
    const result = {
      status: 'error',
      code: 'DOCS_NOT_FOUND',
      message: `The 'docs/' directory was not found in '${posixCwd}'. No active or previous workflows exist.`,
      docs_path: posixDocsDir,
      available_objectives: [],
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }

  const allResumable = scanDocsDirectory(docsDir);

  if (allResumable.length === 0) {
    const result = {
      status: 'empty',
      code: 'NO_STATE_FILES',
      message: `The 'docs/' directory exists, but no subdirectories contain a 'state.md' file.`,
      docs_path: posixDocsDir,
      available_objectives: [],
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }

  // If user provided a specific objective
  if (options.objective) {
    const target = options.objective.trim();
    const matched = allResumable.find(
      (item) => item.objective.toLowerCase() === target.toLowerCase()
    );

    if (matched) {
      const result = {
        status: 'found',
        code: 'OBJECTIVE_MATCHED',
        message: `Found resumable workflow for objective '${target}'.`,
        target: target,
        workflow: matched.workflow,
        state_file: matched.path,
        metadata: matched,
        available_objectives: allResumable,
      };
      console.log(JSON.stringify(result, null, 2));
      process.exit(0);
    } else {
      const result = {
        status: 'not_found',
        code: 'OBJECTIVE_NOT_FOUND',
        message: `Objective '${target}' was not found with a valid state.md.`,
        target: target,
        available_objectives: allResumable,
      };
      console.log(JSON.stringify(result, null, 2));
      process.exit(0);
    }
  }

  // No specific objective requested: return the list
  const result = {
    status: 'list',
    code: 'SELECT_OBJECTIVE',
    message: `Found ${allResumable.length} resumable workflow(s). Please choose an objective to resume.`,
    available_objectives: allResumable,
  };
  console.log(JSON.stringify(result, null, 2));
}

main();
