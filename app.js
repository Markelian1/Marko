 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/app.js b/app.js
new file mode 100644
index 0000000000000000000000000000000000000000..b5004c2244d2bdb7925b3bb3e246d53975fc36c8
--- /dev/null
+++ b/app.js
@@ -0,0 +1,142 @@
+const STORAGE_KEY = "invoice_app_records_v1";
+
+const form = document.getElementById("invoice-form");
+const tableBody = document.getElementById("invoiceTableBody");
+const statsEl = document.getElementById("stats");
+const searchEl = document.getElementById("search");
+const statusFilterEl = document.getElementById("statusFilter");
+const clearAllEl = document.getElementById("clearAll");
+const emptyTemplate = document.getElementById("empty-row-template");
+
+let invoices = loadInvoices();
+
+form.addEventListener("submit", (event) => {
+  event.preventDefault();
+
+  const invoice = {
+    id: crypto.randomUUID(),
+    invoiceNumber: form.invoiceNumber.value.trim(),
+    client: form.client.value.trim(),
+    date: form.date.value,
+    amount: Number(form.amount.value),
+    status: form.status.value,
+  };
+
+  if (!invoice.invoiceNumber || !invoice.client || !invoice.date || Number.isNaN(invoice.amount)) {
+    alert("Ju lutem plotësoni të gjitha fushat në mënyrë korrekte.");
+    return;
+  }
+
+  invoices.unshift(invoice);
+  persist();
+  form.reset();
+  render();
+});
+
+searchEl.addEventListener("input", render);
+statusFilterEl.addEventListener("change", render);
+clearAllEl.addEventListener("click", () => {
+  const shouldDelete = confirm("A jeni i sigurt që doni të fshini të gjitha faturat?");
+  if (!shouldDelete) return;
+
+  invoices = [];
+  persist();
+  render();
+});
+
+function loadInvoices() {
+  try {
+    return JSON.parse(localStorage.getItem(STORAGE_KEY)) ?? [];
+  } catch {
+    return [];
+  }
+}
+
+function persist() {
+  localStorage.setItem(STORAGE_KEY, JSON.stringify(invoices));
+}
+
+function formatCurrency(value) {
+  return new Intl.NumberFormat("sq-AL", { style: "currency", currency: "EUR" }).format(value);
+}
+
+function normalize(value) {
+  return value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
+}
+
+function deleteInvoice(id) {
+  invoices = invoices.filter((item) => item.id !== id);
+  persist();
+  render();
+}
+
+function createStatusBadge(status) {
+  const className = normalize(status).replace(/\s+/g, "-");
+  return `<span class="status ${className}">${status}</span>`;
+}
+
+function getFilteredInvoices() {
+  const query = normalize(searchEl.value.trim());
+  const selectedStatus = statusFilterEl.value;
+
+  return invoices.filter((item) => {
+    const matchesStatus = selectedStatus === "all" || item.status === selectedStatus;
+    const haystack = normalize(`${item.invoiceNumber} ${item.client}`);
+    const matchesSearch = !query || haystack.includes(query);
+    return matchesStatus && matchesSearch;
+  });
+}
+
+function renderStats(data) {
+  const total = data.reduce((sum, item) => sum + item.amount, 0);
+  const paid = data.filter((i) => i.status === "E paguar").reduce((sum, item) => sum + item.amount, 0);
+  const unpaid = data.filter((i) => i.status === "E papaguar").reduce((sum, item) => sum + item.amount, 0);
+
+  statsEl.innerHTML = `
+    <article class="stat">
+      <h3>Numri i faturave</h3>
+      <p>${data.length}</p>
+    </article>
+    <article class="stat">
+      <h3>Shuma totale</h3>
+      <p>${formatCurrency(total)}</p>
+    </article>
+    <article class="stat">
+      <h3>Të paguara</h3>
+      <p>${formatCurrency(paid)}</p>
+    </article>
+    <article class="stat">
+      <h3>Të papaguara</h3>
+      <p>${formatCurrency(unpaid)}</p>
+    </article>
+  `;
+}
+
+function render() {
+  const data = getFilteredInvoices();
+  renderStats(data);
+
+  tableBody.innerHTML = "";
+
+  if (data.length === 0) {
+    tableBody.append(emptyTemplate.content.cloneNode(true));
+    return;
+  }
+
+  for (const item of data) {
+    const row = document.createElement("tr");
+    row.innerHTML = `
+      <td>${item.invoiceNumber}</td>
+      <td>${item.client}</td>
+      <td>${item.date}</td>
+      <td>${formatCurrency(item.amount)}</td>
+      <td>${createStatusBadge(item.status)}</td>
+      <td><button class="small-btn" data-id="${item.id}">Fshi</button></td>
+    `;
+
+    row.querySelector("button").addEventListener("click", () => deleteInvoice(item.id));
+    tableBody.append(row);
+  }
+}
+
+render();
 
EOF
)
