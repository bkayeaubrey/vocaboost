// Test script to simulate the Dart app's request to the proxy
const http = require('http');

const proxyUrl = 'https://us-central1-vocaboost-fb.cloudfunctions.net/openaiProxy';

const testPayload = {
  model: 'gpt-3.5-turbo',
  messages: [
    {
      role: 'system',
      content: 'You are a Mindanao Bisaya vocabulary expert and validator. Work with Bisaya/Cebuano words used in Mindanao (Davao, Butuan, Agusan, Surigao, CDO, etc.). Accept common Bisaya words used in Mindanao, even if also used in Central Visayas. Return JSON only. Reject misspellings, English, Tagalog, and internet slang. Accept legitimate Bisaya/Cebuano words used in Mindanao. Use natural conversational Mindanao Bisaya sentences. Bias towards acceptance for common Bisaya vocabulary.'
    },
    {
      role: 'user',
      content: 'Validate this Mindanao Bisaya word and provide a comprehensive JSON dictionary entry:\n\nWord: balay\n\nRequired JSON format (must return ONLY valid JSON, no markdown, no explanations):\n{\n  "valid": <true if valid Mindanao Bisaya word, false otherwise>,\n  "reason": "<explanation if not valid>",\n  "word": "<the word>",\n  "pronunciation": "<IPA pronunciation>",\n  "partOfSpeech": "<noun/verb/adjective/etc>",\n  "meanings": [\n    {\n      "definition": "<primary meaning>",\n      "context": "<when/how to use this meaning>"\n    }\n  ],\n  "examples": [\n    {\n      "sentence": "<natural Mindanao Bisaya sentence using this word>",\n      "translation": "<English translation>"\n    }\n  ],\n  "usage_note": "<deep usage context, when/how to use, cultural significance, regional variations if any>",\n  "synonyms": "<comma-separated list of related Mindanao Bisaya words or phrases>",\n  "confidence": <0-100 integer>,\n  "note": "<null or short note for regional meaning>"\n}'
    }
  ],
  temperature: 0.0,
  max_tokens: 800
};

console.log('[Test] Sending request to proxy...');
console.log('[Test] URL:', proxyUrl);
console.log('[Test] Payload size:', JSON.stringify(testPayload).length, 'bytes');

fetch(proxyUrl, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(testPayload)
})
  .then(response => {
    console.log('[Test] Response status:', response.status);
    console.log('[Test] Response headers:', response.headers);
    return response.json();
  })
  .then(data => {
    console.log('[Test] Response data:', JSON.stringify(data, null, 2));
  })
  .catch(error => {
    console.error('[Test] Error:', error.message);
    if (error.response) {
      console.error('[Test] Response:', error.response);
    }
  });
