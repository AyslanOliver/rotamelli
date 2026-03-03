(() => {
  const API_BASE = 'https://rota-ml-cloudflare-api.ayslano37.workers.dev';
  const btnAdd = document.getElementById('btnAdd');
  const btnLogin = document.getElementById('btnLogin');
  const btnLogout = document.getElementById('btnLogout');
  const msg = document.getElementById('msg');
  const loginMsg = document.getElementById('loginMsg');
  const tblBody = document.querySelector('#tbl tbody');
  const nameEl = document.getElementById('name');
  const emailEl = document.getElementById('email');
  const roleEl = document.getElementById('role');
  const pinEl = document.getElementById('pin');
  const activeEl = document.getElementById('active');
  const loginEmail = document.getElementById('loginEmail');
  const loginPin = document.getElementById('loginPin');
  const loginBox = document.getElementById('login');
  const adminPanel = document.getElementById('adminPanel');

  let token = localStorage.getItem('adminToken') || '';

  async function api(path, opt = {}) {
    const resp = await fetch(API_BASE + path, {
      method: opt.method || 'GET',
      headers: { 'Content-Type': 'application/json' },
      body: opt.body ? JSON.stringify(opt.body) : undefined,
    });
    if (!resp.ok) throw new Error(`Falha: ${resp.status}`);
    return resp.json();
  }
  async function apiAuth(path, opt = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    const resp = await fetch(API_BASE + path, {
      method: opt.method || 'GET',
      headers,
      body: opt.body ? JSON.stringify(opt.body) : undefined,
    });
    if (!resp.ok) throw new Error(`Falha: ${resp.status}`);
    return resp.json();
  }

  async function loadUsers() {
    try {
      if (!token) { msg.textContent = 'Faça login para carregar usuários.'; return; }
      const users = await apiAuth('/api/users');
      tblBody.innerHTML = '';
      users.forEach(u => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${u.id}</td>
          <td>${u.name ?? ''}</td>
          <td>${u.email ?? ''}</td>
          <td>${u.role ?? ''}</td>
          <td>${Number(u.active) ? 'Sim' : 'Não'}</td>
          <td class="actions">
            <button data-act="edit" data-id="${u.id}">Editar</button>
            <button data-act="del" data-id="${u.id}">Excluir</button>
          </td>
        `;
        tblBody.appendChild(tr);
      });
      msg.textContent = `Carregados ${users.length} usuário(s).`;
    } catch (e) {
      msg.textContent = `Erro: ${e.message}`;
    }
  }
  function setLoggedIn(v) {
    if (v) {
      loginBox.style.display = 'none';
      btnLogout.style.display = '';
      adminPanel.style.display = '';
    } else {
      loginBox.style.display = '';
      btnLogout.style.display = 'none';
      adminPanel.style.display = 'none';
    }
  }
  async function doLogin() {
    loginMsg.textContent = '';
    try {
      const res = await api('/api/login', { method: 'POST', body: { email: loginEmail.value.trim(), pin: loginPin.value.trim() } });
      if (!res?.ok || !res?.token) throw new Error(res?.error || 'Falha no login');
      token = res.token;
      localStorage.setItem('adminToken', token);
      setLoggedIn(true);
      await loadUsers();
    } catch (e) {
      loginMsg.textContent = `Erro: ${e.message}`;
    }
  }
  function doLogout() {
    token = '';
    localStorage.removeItem('adminToken');
    setLoggedIn(false);
  }

  async function addUser() {
    const body = {
      name: nameEl.value.trim(),
      email: emailEl.value.trim(),
      role: roleEl.value,
      pin: pinEl.value,
      active: Number(activeEl.value),
    };
    try {
      await apiAuth('/api/users', { method: 'POST', body });
      nameEl.value = ''; emailEl.value = ''; pinEl.value = ''; roleEl.value = 'user'; activeEl.value = '1';
      msg.textContent = 'Usuário criado.';
      await loadUsers();
    } catch (e) {
      msg.textContent = `Erro ao criar: ${e.message}`;
    }
  }

  tblBody.addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button');
    if (!btn) return;
    const id = Number(btn.dataset.id);
    const act = btn.dataset.act;
    if (act === 'del') {
      if (!confirm('Excluir usuário?')) return;
      try {
        await apiAuth(`/api/users/${id}`, { method: 'DELETE' });
        await loadUsers();
      } catch (e) {
        msg.textContent = `Erro ao excluir: ${e.message}`;
      }
    } else if (act === 'edit') {
      const name = prompt('Nome:');
      const email = prompt('E-mail:');
      const role = prompt('Perfil (user/admin):');
      const active = prompt('Ativo (1/0):');
      const pin = prompt('PIN (opcional):');
      const body = {};
      if (name) body.name = name;
      if (email) body.email = email;
      if (role) body.role = role;
      if (active) body.active = Number(active);
      if (pin) body.pin = pin;
      try {
        await apiAuth(`/api/users/${id}`, { method: 'PUT', body });
        await loadUsers();
      } catch (e) {
        msg.textContent = `Erro ao atualizar: ${e.message}`;
      }
    }
  });

  btnAdd.addEventListener('click', addUser);
  btnLogin.addEventListener('click', doLogin);
  btnLogout.addEventListener('click', doLogout);

  setLoggedIn(Boolean(token));
  if (token) loadUsers();
})();
