const STORAGE_KEY = "invoice_records_v1";

const invoiceForm = document.getElementById("invoiceForm");
const invoiceTableBody = document.getElementById("invoiceTableBody");
const searchInput = document.getElementById("searchInput");
const totalInvoices = document.getElementById("totalInvoices");
const totalAmount = document.getElementById("totalAmount");
const exportCsvButton = document.getElementById("exportCsv");
const clearAllButton = document.getElementById("clearAll");
const invoiceRowTemplate = document.getElementById("invoiceRowTemplate");

let invoices = loadInvoices();

invoiceForm.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(invoiceForm);
  const newInvoice = {
    id: crypto.randomUUID(),
    invoiceNumber: formData.get("invoiceNumber") || document.getElementById("invoiceNumber").value.trim(),
    invoiceDate: formData.get("invoiceDate") || document.getElementById("invoiceDate").value,
    clientName: formData.get("clientName") || document.getElementById("clientName").value.trim(),
    amount: Number(formData.get("amount") || document.getElementById("amount").value),
    status: formData.get("status") || document.getElementById("status").value,
    description: formData.get("description") || document.getElementById("description").value.trim()
  };

  if (!newInvoice.invoiceNumber || !newInvoice.clientName || !newInvoice.invoiceDate || Number.isNaN(newInvoice.amount)) {
    alert("Ju lutem plotësoni të gjitha fushat e detyrueshme.");
    return;
  }

  invoices.unshift(newInvoice);
  saveInvoices();
  renderInvoices();
  invoiceForm.reset();
});

searchInput.addEventListener("input", () => {
  renderInvoices();
});

invoiceTableBody.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) return;

  if (target.dataset.action === "delete") {
    const id = target.closest("tr")?.dataset.id;
    if (!id) return;

    invoices = invoices.filter((invoice) => invoice.id !== id);
    saveInvoices();
    renderInvoices();
  }
});

exportCsvButton.addEventListener("click", () => {
  if (!invoices.length) {
    alert("Nuk ka fatura për eksport.");
    return;
  }

  const headers = ["Nr. Fature", "Data", "Klienti", "Vlera", "Statusi", "Pershkrimi"];
  const rows = invoices.map((invoice) => [
    invoice.invoiceNumber,
    invoice.invoiceDate,
    invoice.clientName,
    invoice.amount.toFixed(2),
    invoice.status,
    invoice.description || ""
  ]);

  const csv = [headers, ...rows]
    .map((row) => row.map(escapeCsvValue).join(","))
    .join("\n");

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `fatura-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
});

clearAllButton.addEventListener("click", () => {
  if (!invoices.length) return;
  const confirmed = confirm("A jeni të sigurt që doni të fshini të gjitha faturat?");
  if (!confirmed) return;

  invoices = [];
  saveInvoices();
  renderInvoices();
});

renderInvoices();

function loadInvoices() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveInvoices() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(invoices));
}

function renderInvoices() {
  const query = searchInput.value.trim().toLowerCase();
  const filteredInvoices = invoices.filter((invoice) => {
    const haystack = `${invoice.invoiceNumber} ${invoice.clientName}`.toLowerCase();
    return haystack.includes(query);
  });

  invoiceTableBody.innerHTML = "";

  filteredInvoices.forEach((invoice) => {
    const row = invoiceRowTemplate.content.cloneNode(true);
    const tr = row.querySelector("tr");
    tr.dataset.id = invoice.id;

    row.querySelector('[data-field="invoiceNumber"]').textContent = invoice.invoiceNumber;
    row.querySelector('[data-field="invoiceDate"]').textContent = invoice.invoiceDate;
    row.querySelector('[data-field="clientName"]').textContent = invoice.clientName;
    row.querySelector('[data-field="amount"]').textContent = `${invoice.amount.toFixed(2)} €`;
    row.querySelector('[data-field="status"]').textContent = invoice.status;
    row.querySelector('[data-field="description"]').textContent = invoice.description || "-";

    invoiceTableBody.appendChild(row);
  });

  totalInvoices.textContent = String(invoices.length);
  const sum = invoices.reduce((acc, item) => acc + Number(item.amount), 0);
  totalAmount.textContent = `${sum.toFixed(2)} €`;
}

function escapeCsvValue(value) {
  const safe = String(value ?? "");
  if (safe.includes('"') || safe.includes(",") || safe.includes("\n")) {
    return `"${safe.replaceAll('"', '""')}"`;
  }
  return safe;
}
