# SKYORA v2.0 API 연동 준비 패치

- Cloudflare Worker 서버측 기상청 API 프록시 추가 (`skyora_proxy/`)
- GitHub Actions에서 `vars.SKYORA_PROXY_URL`을 Flutter 컴파일 정의로 전달
- 기존 앱 UI/아이콘/지역 샘플 데이터는 변경하지 않음
- 전국 읍면동 DB, 실시간 실황 API, 대기질 및 레이더는 아직 미구현
- 실제 API 키로 호출 및 APK 실행 테스트는 아직 미완료
