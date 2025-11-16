export const BASE_URL = "https://supernotable-lorenza-unsieged.ngrok-free.dev/web";

/**
 * @param {string} endpoint - API endpoint(ex: '/get_stds', '/login')
 * @param {string} method - HTTP method('GET', 'POST', etc...)
 * @param {Object} [body] - request body
 * @param {Object} [headers] - add headers
 * @returns {Promise<any>} - json data or text from server
 */

export async function callAPI(endpoint, method = "GET", body = null, headers = {}) {
  try {
    const fetchOptions = {
      method,
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "1",
        ...headers,
      },
    };

    if (body && method.toUpperCase() !== "GET") {
      fetchOptions.body = JSON.stringify(body);
    }

    const res = await fetch(`${BASE_URL}${endpoint}`, fetchOptions);

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    return res.json();

  } catch (err) {
    console.error(`API 호출 실패 [${method} ${endpoint}]`, err);
    return null;
  }
}
