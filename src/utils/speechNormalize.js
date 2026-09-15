/**
 * Speech-to-text normalization utilities.
 * Converts spoken phrases into structured format for each field.
 */

// ─── Word → digit mappings ────────────────────────────────────────────────────
const WORD_DIGITS = {
  zero: '0', oh: '0', o: '0',
  one: '1', won: '1',
  two: '2', to: '2', too: '2',
  three: '3',
  four: '4', for: '4', fore: '4',
  five: '5',
  six: '6',
  seven: '7',
  eight: '8', ate: '8',
  nine: '9', nein: '9',
};

const KNOWN_ACRONYMS = new Set(['DPS', 'KV', 'CBSE', 'ICSE', 'IIT', 'NIT', 'BIT', 'ST', 'JNV', 'IIIT']);

function stripPrefix(text, patterns) {
  let result = text.trim();
  for (const pattern of patterns) {
    result = result.replace(pattern, '').trim();
  }
  return result;
}

/**
 * Capitalize words properly.
 */
function titleCase(str) {
  return str
    .trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map((w) => {
      if (!w) return '';
      const upper = w.toUpperCase();
      if (KNOWN_ACRONYMS.has(upper)) return upper;
      return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
    })
    .join(' ');
}

/**
 * Normalize spoken Name.
 * "My name is Mr priyansh goyal" → "Priyansh Goyal"
 * "My name is Mr. Priyansh Goyal" → "Priyansh Goyal"
 */
export function normalizeName(transcript) {
  if (!transcript || typeof transcript !== 'string') return '';

  let text = stripPrefix(transcript.trim(), [
    /^my name is\s+/i,
    /^my name's\s+/i,
    /^i am\s+/i,
    /^i'm\s+/i,
    /^this is\s+/i,
    /^call me\s+/i,
    /^name is\s+/i,
    /^name\s+/i,
  ]);

  // Strip honorific titles (Mr., Mr, Mrs., Mrs, Ms., Ms, Miss, Shri, Smt, Dr., Dr) at the start of name
  text = text.replace(/^(mr\.|mr|mrs\.|mrs|ms\.|ms|miss|shri|smt|dr\.|dr|prof\.|prof)\b\s*/i, '');

  // Remove unwanted punctuation except hyphens/spaces
  text = text.replace(/[^\w\s-]/g, '').trim();

  return titleCase(text) || titleCase(transcript);
}

/**
 * Normalize spoken Father's Name.
 * "My father's name is Mr Rajesh Goyal" → "Rajesh Goyal"
 */
export function normalizeFatherName(transcript) {
  if (!transcript || typeof transcript !== 'string') return '';

  let text = stripPrefix(transcript.trim(), [
    /^my father's name is\s+/i,
    /^my father name is\s+/i,
    /^my father's name\s+/i,
    /^my father name\s+/i,
    /^father's name is\s+/i,
    /^father name is\s+/i,
    /^father's name\s+/i,
    /^father name\s+/i,
    /^father\s+/i,
  ]);

  text = text.replace(/^(mr\.|mr|shri|dr\.|dr|prof\.|prof)\b\s*/i, '');
  text = text.replace(/[^\w\s-]/g, '').trim();

  return titleCase(text) || titleCase(transcript);
}

/**
 * Normalize spoken Class.
 * "I study in class 10th" → "10th"
 */
export function normalizeClass(transcript) {
  if (!transcript || typeof transcript !== 'string') return '';

  let text = stripPrefix(transcript.trim(), [
    /^my class is\s+/i,
    /^i am in class\s+/i,
    /^i study in class\s+/i,
    /^class is\s+/i,
    /^class\s+/i,
    /^standard\s+/i,
    /^grade\s+/i,
  ]);

  return titleCase(text) || transcript.trim();
}

/**
 * Normalize spoken phone number into a 10-digit string.
 * Strictly extracts digits only; returns empty string if no valid digits found.
 */
export function normalizePhone(transcript) {
  if (!transcript || typeof transcript !== 'string') return '';

  const text = stripPrefix(transcript.toLowerCase(), [
    /^my phone(?: number)? is\s+/,
    /^my number is\s+/,
    /^call me (?:at|on)\s+/,
    /^phone(?: number)? is\s+/,
    /^number is\s+/,
    /^it is\s+/,
    /^it's\s+/,
  ]);

  const words = text
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);

  let digits = '';
  for (const word of words) {
    if (/^\d+$/.test(word)) {
      digits += word;
    } else if (WORD_DIGITS[word] !== undefined) {
      digits += WORD_DIGITS[word];
    }
  }

  digits = digits.replace(/\D/g, '');

  // Strictly return digits only; if no valid digits, return empty string (NEVER return transcript fallback!)
  if (!digits || digits.length < 5) {
    return '';
  }

  return digits.slice(0, 10);
}

/**
 * Normalize spoken school name.
 */
export function normalizeSchool(transcript) {
  const text = stripPrefix(transcript.trim(), [
    /^my school(?: name)? is\s+/i,
    /^i study at\s+/i,
    /^i go to\s+/i,
    /^i am from\s+/i,
    /^i'm from\s+/i,
    /^school is\s+/i,
    /^school name is\s+/i,
    /^school\s+/i,
    /^i am studying at\s+/i,
    /^i'm studying at\s+/i,
  ]);

  return titleCase(text) || transcript;
}

/**
 * Normalize spoken City.
 * "My city is Bhopal" → "Bhopal"
 * "I live in New Delhi" → "New Delhi"
 */
export function normalizeCity(transcript) {
  const text = stripPrefix(transcript.trim(), [
    /^my city is\s+/i,
    /^my location is\s+/i,
    /^i live in\s+/i,
    /^i am from\s+/i,
    /^i'm from\s+/i,
    /^city is\s+/i,
    /^city\s+/i,
    /^from\s+/i,
  ]);

  return titleCase(text) || transcript;
}
