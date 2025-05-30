import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 50 }, // Ramp up
    { duration: '3m', target: 50 }, // Sustain
    { duration: '2m', target: 0 },  // Ramp down
  ],
};

export default function () {
  http.get('http://34.160.254.13/api/v1/notifications/health');
  sleep(1);
}