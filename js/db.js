// ============================================================
// EAS AI Dashboard — Database / Data Layer
// Phase 3: Full Supabase integration (re-fetch per quarter)
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

  function getQuarters() { return _quarters; }

  function getActiveQuarter() {
    return _quarters.find(q => q.is_active) || _quarters[_quarters.length - 1];
  }

  function getSelectedQuarter() {
    if (!_selectedQuarter) {
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

  function getQuarterLabel(quarterId) {
    if (quarterId === 'all') return 'All Time';
    const q = _quarters.find(q => q.id === quarterId);
    return q ? q.label : quarterId;
  }

  // ---- Quarter Selector UI ----

  function populateQuarterSelector(selectId = 'quarter-selector') {
    const select = document.getElementById(selectId);
    if (!select) return;

    select.innerHTML = '';

    const allOpt = document.createElement('option');
    allOpt.value = 'all';
    allOpt.textContent = 'All Time';
    select.appendChild(allOpt);

    _quarters.forEach(q => {
      const opt = document.createElement('option');
      opt.value = q.id;
      opt.textContent = q.label + (q.is_active ? ' (Current)' : '') + (q.is_locked ? ' 🔒' : '');
      select.appendChild(opt);
    });

    select.value = getSelectedQuarter();

    select.addEventListener('change', (e) => {
      setSelectedQuarter(e.target.value);
      window.dispatchEvent(new CustomEvent('quarter-changed', { detail: { quarter: e.target.value } }));
    });
  }

  // ---- Quarter Comparison Helpers ----

  function getPreviousQuarter(quarterId) {
    if (!quarterId || quarterId === 'all') return null;
    const idx = _quarters.findIndex(q => q.id === quarterId);
    return idx > 0 ? _quarters[idx - 1].id : null;
  }

  function calcDelta(current, previous) {
    if (!previous || previous === 0) return null;
    return ((current - previous) / previous) * 100;
  }

  function formatDelta(delta) {
    if (delta === null || delta === undefined) return '';
    const sign = delta >= 0 ? '↑' : '↓';
    const color = delta >= 0 ? 'var(--success)' : 'var(--danger)';
    return `<span style="color:${color};font-size:12px;font-weight:600">${sign} ${Math.abs(delta).toFixed(1)}%</span>`;
  }

  // ===========================================================
  // Supabase Data Queries — Full Fetch Layer (Phase 3)
  // ===========================================================

  /**
   * Fetch practice summary (quarter-aware via RPC).
   * If quarterId is 'all' or null, fetches aggregated across all quarters.
   * Returns array of practice objects matching the APP_DATA.summary.practices shape.
   */
  async function fetchPracticeSummary(quarterId) {
    const qid = (!quarterId || quarterId === 'all') ? null : quarterId;
    const { data, error } = await sb.rpc('get_practice_summary', { p_quarter_id: qid });
    if (error) {
      console.error('fetchPracticeSummary error:', error.message);
      return [];
    }
    // Transform snake_case DB → camelCase APP_DATA shape
    return (data || []).map(p => ({
      name:         p.practice,
      head:         p.head,
      spoc:         p.spoc,
      tasks:        Number(p.tasks) || 0,
      timeWithout:  Number(p.time_without) || 0,
      timeWith:     Number(p.time_with) || 0,
      timeSaved:    Number(p.time_saved) || 0,
      efficiency:   Number(p.efficiency_pct) || 0,
      quality:      Number(p.avg_quality) || 0,
      completed:    Number(p.completed) || 0,
      projects:     Number(p.project_count) || 0,
      licensedUsers: Number(p.licensed_users) || 0,
      activeUsers:  Number(p.active_users) || 0
    }));
  }

  /**
   * Fetch tasks from Supabase (quarter-filtered).
   * Returns array matching APP_DATA.tasks shape.
   */
  async function fetchTasks(quarterId) {
    let query = sb.from('tasks').select('*').order('week_start', { ascending: false });
    if (quarterId && quarterId !== 'all') {
      query = query.eq('quarter_id', quarterId);
    }
    const { data, error } = await query;
    if (error) {
      console.error('fetchTasks error:', error.message);
      return [];
    }
    return (data || []).map(t => ({
      id:          t.id,
      practice:    t.practice,
      week:        t.week_number,
      weekStart:   t.week_start,
      weekEnd:     t.week_end,
      project:     t.project,
      projectCode: t.project_code,
      employee:    t.employee_name,
      employeeEmail: t.employee_email,
      task:        t.task_description,
      category:    t.category,
      aiTool:      t.ai_tool,
      prompt:      t.prompt_used,
      timeWithout: Number(t.time_without_ai) || 0,
      timeWith:    Number(t.time_with_ai) || 0,
      timeSaved:   Number(t.time_saved) || 0,
      efficiency:  Number(t.efficiency) || 0,
      quality:     Number(t.quality_rating) || 0,
      status:      t.status,
      notes:       t.notes,
      quarterId:   t.quarter_id
    }));
  }

  /**
   * Fetch accomplishments (quarter-filtered).
   * Returns array matching APP_DATA.accomplishments shape.
   */
  async function fetchAccomplishments(quarterId) {
    let query = sb.from('accomplishments').select('*').order('date', { ascending: false });
    if (quarterId && quarterId !== 'all') {
      query = query.eq('quarter_id', quarterId);
    }
    const { data, error } = await query;
    if (error) {
      console.error('fetchAccomplishments error:', error.message);
      return [];
    }
    return (data || []).map(a => ({
      id:            a.id,
      date:          a.date,
      practice:      a.practice,
      project:       a.project,
      projectCode:   a.project_code,
      spoc:          a.spoc,
      employees:     a.employees,
      title:         a.title,
      details:       a.details,
      aiTool:        a.ai_tool,
      category:      a.category,
      before:        a.before_baseline,
      after:         a.after_result,
      impact:        a.quantified_impact,
      businessGains: a.business_gains,
      cost:          a.cost,
      effortSaved:   Number(a.effort_saved) || 0,
      status:        a.status,
      evidence:      a.evidence,
      notes:         a.notes,
      quarterId:     a.quarter_id
    }));
  }

  /**
   * Fetch copilot users (NOT quarter-filtered — global license list).
   * Returns array matching APP_DATA.copilotUsers shape.
   */
  async function fetchCopilotUsers() {
    const { data, error } = await sb
      .from('copilot_users')
      .select('*')
      .order('practice', { ascending: true })
      .order('name', { ascending: true });
    if (error) {
      console.error('fetchCopilotUsers error:', error.message);
      return [];
    }
    return (data || []).map(u => ({
      id:            u.id,
      practice:      u.practice,
      name:          u.name,
      email:         u.email,
      skill:         u.role_skill,
      status:        u.status,
      hasLoggedTask: u.has_logged_task,
      lastTaskDate:  u.last_task_date,
      remarks:       u.remarks,
      copilotAccessDate: u.copilot_access_date
    }));
  }

  /**
   * Fetch projects (NOT quarter-filtered — global project list).
   * Returns array matching APP_DATA.projects shape.
   */
  async function fetchProjects() {
    const { data, error } = await sb
      .from('projects')
      .select('*')
      .order('practice', { ascending: true })
      .order('project_name', { ascending: true });
    if (error) {
      console.error('fetchProjects error:', error.message);
      return [];
    }
    return (data || []).map(p => ({
      id:             p.id,
      practice:       p.practice,
      projectCode:    p.project_code,
      contractNumber: p.contract_number,
      customer:       p.customer,
      contractValue:  Number(p.contract_value) || 0,
      startDate:      p.start_date,
      endDate:        p.end_date,
      projectName:    p.project_name,
      revenueType:    p.revenue_type,
      lineType:       p.line_type,
      projectManager: p.project_manager,
      isActive:       p.is_active
    }));
  }

  /**
   * Fetch LOV values (lists of values for dropdowns).
   * Returns object: { taskCategories: [], aiTools: [] }
   */
  async function fetchLovs() {
    const { data, error } = await sb
      .from('lovs')
      .select('*')
      .order('sort_order', { ascending: true });
    if (error) {
      console.error('fetchLovs error:', error.message);
      return { taskCategories: [], aiTools: [] };
    }
    const lovs = { taskCategories: [], aiTools: [] };
    (data || []).forEach(row => {
      if (row.category === 'task_category') lovs.taskCategories.push(row.value);
      else if (row.category === 'ai_tool') lovs.aiTools.push(row.value);
    });
    return lovs;
  }

  /**
   * Fetch quarter summary from Supabase view.
   */
  async function fetchQuarterSummary() {
    const { data, error } = await sb.from('quarter_summary').select('*');
    if (error) { console.error('fetchQuarterSummary error:', error.message); return []; }
    return data || [];
  }

  // ===========================================================
  // Unified Data Loader — replaces inline APP_DATA
  // ===========================================================

  /**
   * Fetch all dashboard data for a given quarter.
   * Returns an object matching the legacy APP_DATA shape:
   * {
   *   summary: { practices: [...], totals: {...} },
   *   tasks: [...],
   *   accomplishments: [...],
   *   copilotUsers: [...],
   *   projects: [...],
   *   lovs: { taskCategories: [...], aiTools: [...] }
   * }
   */
  async function fetchAllData(quarterId) {
    // Parallel fetch for speed
    const [practices, tasks, accomplishments, copilotUsers, projects, lovs] = await Promise.all([
      fetchPracticeSummary(quarterId),
      fetchTasks(quarterId),
      fetchAccomplishments(quarterId),
      fetchCopilotUsers(),
      fetchProjects(),
      fetchLovs()
    ]);

    // Compute totals from practice summaries
    const totals = practices.reduce((acc, p) => {
      acc.tasks       += p.tasks;
      acc.timeWithout += p.timeWithout;
      acc.timeWith    += p.timeWith;
      acc.timeSaved   += p.timeSaved;
      acc.completed   += p.completed;
      acc.projects    += p.projects;
      return acc;
    }, { tasks: 0, timeWithout: 0, timeWith: 0, timeSaved: 0, completed: 0, projects: 0 });

    // Calculate overall efficiency and quality from totals
    totals.efficiency = totals.timeWithout > 0
      ? (totals.timeSaved / totals.timeWithout * 100)
      : 0;

    // Weighted average quality (by task count)
    const qualitySum = practices.reduce((s, p) => s + (p.quality * p.tasks), 0);
    totals.quality = totals.tasks > 0 ? qualitySum / totals.tasks : 0;

    return {
      summary: { practices, totals },
      tasks,
      accomplishments,
      copilotUsers,
      projects,
      lovs
    };
  }

  // ===========================================================
  // Public API
  // ===========================================================

  return {
    // Quarter management
    loadQuarters,
    getQuarters,
    getActiveQuarter,
    getSelectedQuarter,
    setSelectedQuarter,
    getQuarterLabel,
    populateQuarterSelector,
    getPreviousQuarter,
    calcDelta,
    formatDelta,

    // Data queries
    fetchTasks,
    fetchPracticeSummary,
    fetchQuarterSummary,
    fetchAccomplishments,
    fetchCopilotUsers,
    fetchProjects,
    fetchLovs,
    fetchAllData
  };
})();
