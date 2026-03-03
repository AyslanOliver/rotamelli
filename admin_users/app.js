(() => {
  const apiInput = document.getElementById('apiBase');
  const btnLoad = document.getElementById('btnLoad');
  const btnAdd = document.getElementById('btnAdd');
  const msg = document.getElementById('msg');
  const tblBody = document.querySelector('#tbl tbody');
  const nameEl = document.getElementById('name');
  const emailEl = document.getElementById('email');
  const roleEl = document.getElementById('role');
  const pinEl = document.getElementById('pin');
  const activeEl = document.getElementById('active');

  apiInput.value = localStorage.getItem('apiBase') || '';

  async function api(path, opt = {}) {
    const base = apiInput.value.trim().replace(/\/+$/, ''); // remove barras finais
    if (!base) throw new Error('Informe API Base URL');
    const resp = await fetch(base + path, {
      method: opt.method || 'GET',
      headers: { 'Content-Type': 'application/json' },
      body: opt.body ? JSON.stringify(opt.body) : undefined,
    });
    if (!resp.ok) throw new Error(`Falha: ${resp.status}`);
    return resp.json();
  }

  async function loadUsers() {
    try {
      localStorage.setItem('apiBase', apiInput.value.trim());
      const users = await api('/api/users');
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

  async function addUser() {
    const body = {
      name: nameEl.value.trim(),
      email: emailEl.value.trim(),
      role: roleEl.value,
      pin: pinEl.value,
      active: Number(activeEl.value),
    };
    try {
      await api('/api/users', { method: 'POST', body });
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
        await api(`/api/users/${id}`, { method: 'DELETE' });
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
        await api(`/api/users/${id}`, { method: 'PUT', body });
        await loadUsers();
      } catch (e) {
        msg.textContent = `Erro ao atualizar: ${e.message}`;
      }
    }
  });

  btnLoad.addEventListener('click', loadUsers);
  btnAdd.addEventListener('click', addUser);
})();
