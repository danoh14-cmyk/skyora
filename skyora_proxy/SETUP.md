# SKYORA 기상청 API 프록시 연결

1. 공공데이터포털 https://www.data.go.kr/data/15084084/openapi.do 에서 **기상청_단기예보 조회서비스** 활용신청 및 인증키 발급.
2. Cloudflare 계정에서 Workers & Pages → Create Worker. 이 폴더의 `worker.js` 코드를 배포하거나 Wrangler CLI로 `npx wrangler deploy`.
3. Worker Settings → Variables and Secrets → Add → **Secret**: `KMA_SERVICE_KEY` = 발급받은 **Decoding** 인증키 (Encoding 키만 있다면 URL 디코딩한 원문을 넣어야 함). 키는 절대 GitHub에 커밋하지 말 것.
4. `https://<worker-name>.<account>.workers.dev/forecast?base_date=YYYYMMDD&base_time=0200&nx=60&ny=127` 같은 형태로 테스트. `base_date`는 오늘 또는 최근 발표 날짜로 바꾸고 실제 발표시각을 사용.
5. GitHub 저장소 Settings → Secrets and variables → Actions → Variables → New repository variable: `SKYORA_PROXY_URL` = `https://<worker-name>.<account>.workers.dev/forecast`.
6. GitHub Actions 수동 빌드. `main.yml`이 `--dart-define=SKYORA_PROXY_URL=...`를 전달함. 변수 값은 비밀 키가 아닌 공개 프록시 URL이어야 함.

주의: 현재는 공개 엔드포인트이며 사용자별 인증, 속도 제한, 악용 방지 및 모니터링을 추가하기 전에는 실서비스 운영에 적합하지 않습니다. 기상청 실제 응답은 키 발급 전 테스트하지 못했습니다. 캐시와 파라미터 검증은 최소한의 방어입니다.
