// ============================================================
// EAS AI Dashboard — Database / Quarter Module
// Phase 2: Quarter-aware data layer
// ============================================================

const EAS_DB = (() => {
  const sb = getSupabaseClient();

  // ---- Quarter State ----
  let _quarters = [];
  let _selectedQuarter = null; // 'Q1-2026', 'Q2-2026', etc. or 'all'

  /** Fetch all quarters from Supabase */
  async function loadQuarters() {
    const { data, error } = await sb
      .from('quarters')
      .select('*')
      .order('start_date', { ascending: true });

    if (error) {
      console.error('Failed to load quarters:', error.message);
      return [];
    }
    _quarters = data || [];
    return _quarters;
  }

  /** Get all quarters */
  function getQuarters() {
    return _quarters;
  }

  /** Get the active (current) quarter */
  function getActiveQuarter() {
    return _quarters.find(q => q.is_active) || _quarters[_quarters.length - 1];
  }

  /** Get or set selected quarter */
  function getSelectedQuarter() {
    if (!_selectedQuarter) {
      // Try localStorage
      const saved = localStorage.getItem('eas_selected_quarter');
      if (saved) {
        _selectedQuarter = saved;
      } else {
        const active = getActiveQuarter();
        _selectedQuarter = active ? active.id : 'all';
      }
    }
    return _selectedQuarter;
  }

  function setSelectedQuarter(quarterId) {
    _selectedQuarter = quarterId;
    localStorage.setItem('eas_selected_quarter', quarterId);
  }

  /** Get quarter display label */
  function getQuarterLabel(quarterId) {
    if (quarterId === 'all') return 'All Time';
    const q = _quarters.find(q => q.id === quarterId);
    return q ? q.label : quarterId;
  }

  // ---- Quarter Selector UI ----

  /** Populate the quarter selector dropdown */
  function populateQuarterSelector(selectId = 'quarter-selector') {
    const select = document.getElementById(selectId);
    if (!select) return;

    select.innerHTML = '';

    // Add "All Time" option
    const allOpt = document.createElement('option');
    allOpt.value = 'all';
    allOpt.textContent = 'All Time';
    select.appendChild(allOpt);

    // Add quarter options
    _quarters.forEach(q => {
      const opt = document.createElement('option');
      opt.value = q.id;
      opt.textContent = q.label + (q.is_active ? ' (Current)' : '') + (q.is_locked ? ' 🔒' : '');
      select.appendChild(opt);
    });

    // Set current selection
    select.value = getSelectedQuarter();

    // Listen for changes
    select.addEventListener('change', (e) => {
      setSelectedQuarter(e.target.value);
      // Dispatch custom event for page re-renders
      window.dispatchEvent(new CustomEvent('quarter-changed', { detail: { quarter: e.target.value } }));
    });
  }

  // ---- Client-side Quarter Filtering (for data.js) ----

  /** Parse a date string from data.js format (DD/M/YYYY) and return quarter ID */
  function getQuarterFromDate(dateStr) {
    if (!dateStr) return null;
    // Handle DD/M/YYYY or DD/MM/YYYY format
    const parts = dateStr.split('/');
    if (parts.length !== 3) return null;

    const month = parseInt(parts[1], 10);
    const year = parseInt(parts[2], 10);
    if (isNaN(month) || isNaN(year)) return null;

    const quarter = Math.ceil(month / 3);
    return `Q${quarter}-${year}`;
  }

  /** Filter tasks array by selected quarter (client-side, for data.js tasks) */
  function filterByQuarter(tasks, quarterId) {
    if (!quarterId || quarterId === 'all') return tasks;

    return tasks.filter(t => {
      const taskQuarter = getQuarterFromDate(t.weekStart);
      return taskQuarter === quarterId;
    });
  }

  /** Filter accomplishments by quarter (client-side) */
  function filterAccomplishmentsByQuarter(accomplishments, quarterId) {
    if (!quarterId || quarterId === 'all') return accomplishments;

    return accomplishments.filter(a => {
      const accQuarter = getQuarterFromDate(a.date);
      return accQuarter === quarterId;
    });
  }

  // ---- Quarter Comparison Helpers ----

  /** Get previous quarter ID */
  function getPreviousQuarter(quarterId) {
    if (!quarterId || quarterId === 'all') return null;
    const idx = _quarters.findIndex(q => q.id === quarterId);
    return idx > 0 ? _quarters[idx - 1].id : null;
  }

  /** Calculate delta between two values (for comparison) */
  function calcDelta(current, previous) {
    if (!previous || previous === 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /** Format delta as display string */
  function formatDelta(delta) {
    if (delta === null || delta === undefined) return '';
    const sign = delta >= 0 ? '↑' : '↓';
    const color = delta >= 0 ? 'var(--success)' : 'var(--danger)';
    return `<span style="color:${color};font-size:12px;font-weight:600">${sign} ${Math.abs(delta).toFixed(1)}%</span>`;
  }

  // ---- Supabase Data Queries (for future Phase 3 full migration) ----

  /** Fetch tasks from Supabase (quarter-filtered) */
  async function fetchTasks(quarterId) {
    let query = sb.from('tasks').select('*').order('created_at', { ascending: false });
    if (quarterId && quarterId !== 'all') {
      query = query.eq('quarter_id', quarterId);
    }
    const { data, error } = await query;
    if (error) { console.error('fetchTasks error:', error.message); return []; }
    return data || [];
  }

  /** Fetch practice summary from Supabase view */
  async function fetchPracticeSummary() {
    const { data, error } = await sb.from('practice_summary').select('*');
    if (error) { console.error('fetchPracticeSummary error:', error.message); return []; }
    return data || [];
  }

  /** Fetch quarter summary from Supabase view */
  async function fetchQuarterSummary() {
    const { data, error } = await sb.from('quarter_summary').select('*');
    if (error) { console.error('fetchQuarterSummary error:', error.message); return []; }
    return data || [];
  }

  return {
    loadQuarters,
    getQuarters,
    getActiveQuarter,
    getSelectedQuarter,
    setSelectedQuarter,
    getQuarterLabel,
    populateQuarterSelector,
    getQuarterFromDate,
    filterByQuarter,
    filterAccomplishmentsByQuarter,
    getPreviousQuarter,
    calcDelta,
    formatDelta,
    fetchTasks,
    fetchPracticeSummary,
    fetchQuarterSummary
  };
})();
