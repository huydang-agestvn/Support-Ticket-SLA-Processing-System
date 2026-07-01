# Các Tính Năng Hệ Thống Xử Lý SLA Hỗ Trợ Khách Hàng (Support Ticket SLA Processing System)

Tài liệu này tổng hợp toàn bộ các tính năng, giải pháp công nghệ và luồng xử lý nghiệp vụ của hệ thống dựa trên việc phân tích mã nguồn dự án. Hệ thống được xây dựng bằng ngôn ngữ **Go (Golang)** theo kiến trúc **Clean Architecture**, tập trung vào khả năng xử lý đồng thời hiệu năng cao, tích hợp trí tuệ nhân tạo (AI/LLM), cơ chế tìm kiếm vector (RAG) và giám sát tập trung.

---

## 1. Quản lý Ticket & Vòng đời Trạng thái (Ticket FSM)

Hệ thống quản lý vòng đời của các yêu cầu hỗ trợ (Support Tickets) thông qua một Máy trạng thái hữu hạn (**Finite State Machine - FSM**) nghiêm ngặt.

*   **Vòng đời Trạng thái chuẩn**:
    *   `new` (Mới tạo) $\rightarrow$ `assigned` (Đã giao cho Agent) hoặc `cancelled` (Hủy bỏ).
    *   `assigned` $\rightarrow$ `in_progress` (Đang xử lý) hoặc `cancelled`.
    *   `in_progress` $\rightarrow$ `resolved` (Đã giải quyết).
    *   `resolved` $\rightarrow$ `closed` (Đã đóng).
*   **Ràng buộc & Kiểm thử FSM**:
    *   Chỉ cho phép chuyển đổi giữa các trạng thái hợp lệ. Bất kỳ sự dịch chuyển sai lệch nào (ví dụ: từ `new` sang `in_progress` hoặc ngược lại) sẽ bị FSM từ chối và ghi nhận lỗi.
    *   **Phân công nhân sự (Assignee)**: Khi chuyển từ `new` sang `assigned`, bắt buộc phải có thông tin `AssigneeID`. Hệ thống cấm thay đổi Assignee trong các bước chuyển trạng thái tiếp theo để đảm bảo tính chịu trách nhiệm (accountability).
    *   **Logic thời gian (SLA)**: Khi chuyển trạng thái sang `resolved` hoặc `cancelled`, thời điểm thực hiện không được phép trước thời điểm tạo Ticket (`CreatedAt`).

---

## 2. Nhập Dữ Liệu Đồng Thời Hiệu Năng Cao (Batch Import ETL)

Để xử lý việc nhập lượng lớn lịch sử sự kiện của Ticket, hệ thống tích hợp luồng ETL hiệu năng cao.

*   **Bộ xử lý đồng thời (In-Memory Worker Pool)**: Sử dụng mô hình Worker Pool viết bằng Go channels (`jobs` và `results`) phối hợp với `sync.WaitGroup` giúp phân tách và xử lý song song các nhóm sự kiện của từng Ticket cụ thể, tối ưu hóa tài nguyên CPU.
*   **Mô phỏng FSM & Phát hiện Trùng lặp**:
    *   Trước khi ghi xuống DB, mỗi nhóm sự kiện được chạy giả lập qua FSM để xác thực luồng trạng thái.
    *   Kiểm tra trùng lặp sự kiện dựa trên khóa băm (hash key) tạo từ thông tin sự kiện để loại bỏ các sự kiện đã tồn tại trong DB hoặc xuất hiện nhiều lần trong chính file import.
*   **Giao dịch Cơ sở Dữ liệu (DB Transactions)**: Toàn bộ quá trình lưu sự kiện mới và cập nhật trạng thái cuối cùng của Ticket được bọc trong một Transaction duy nhất để đảm bảo tính toàn vẹn dữ liệu (ACID).
*   **Nhật ký Kiểm toán (Audit Logging) & Lưu trữ Đối tượng MinIO**:
    *   Các sự kiện bị lỗi hoặc trùng lặp sẽ bị loại khỏi danh sách ghi DB và được tổng hợp lại thành một báo cáo lỗi định dạng CSV (`import_error_report_[timestamp]_[rand].csv`).
    *   Hệ thống tự động tải tệp CSV này lên **MinIO Object Storage** tại bucket `audit-logs`.
    *   Cung cấp API cho phép các cấp quản lý hoặc Agent tải trực tiếp tệp nhật ký lỗi này để đối soát.

---

## 3. Hệ Thống Phân Loại & Định Tuyến AI Thông Minh (AI Triage & Routing)

Đây là tính năng cốt lõi giúp tự động hóa khâu tiếp nhận Ticket, phân tích mức độ ưu tiên, phòng ban xử lý và đánh giá rủi ro vi phạm SLA (SLA Breach Risk).

### Luồng Triage 5 Lớp (5-Layer Triage Pipeline)

```
[Ticket Input]
      │
      ▼
┌────────────────────────────────────────┐
│ Layer 1: Content Safety & Validation   │ ---> Chặn từ thô tục, spam, vô nghĩa
└────────────────────────────────────────┘
      │
      ▼
┌────────────────────────────────────────┐
│ Layer 2: Rule Engine (Short-Circuit)   │ ---> Khớp từ khóa/Regex từ DB. Có khớp?
└─────────────┬──────────────────────────┘
              │ (Không khớp)
              ▼
┌────────────────────────────────────────┐
│ Layer 3: RAG Retrieval (pgvector)      │ ---> Tìm Ticket tương đồng. Điểm cao?
└─────────────┬──────────────────────────┘
              │ (Không đủ cao - Lấy thêm Context phòng ban/mẫu)
              ▼
┌────────────────────────────────────────┐
│ Layer 4: AI Classification             │ ---> Gọi LLM (Ollama -> Groq -> Gemini)
└─────────────┬──────────────────────────┘
              │ (Thành công / Fallback Heuristics)
              ▼
┌────────────────────────────────────────┐
│ Layer 5: Persistence & Action          │ ---> Lưu DB, sửa đổi Category bất đồng bộ
└────────────────────────────────────────┘
```

1.  **Layer 1: Content Safety Filter & Validation**:
    *   Kiểm tra độ dài nội dung (tối thiểu 10 ký tự).
    *   Chạy qua bộ lọc an toàn để phát hiện từ thô tục, xúc phạm, spam quảng cáo hoặc nội dung vô nghĩa (gibberish).
2.  **Layer 2: Urgency Rule Engine (Động từ Database)**:
    *   Hệ thống truy vấn danh sách `rule_patterns` đang hoạt động trực tiếp từ Database.
    *   Thực hiện so khớp regex hoặc từ khóa với tiêu đề và mô tả Ticket để gán mức độ ưu tiên tức thì (Short-circuit).
    *   **Sửa lỗi phân loại sai (Category Correction)**: Nếu người dùng chọn danh mục sai (ví dụ: chọn IT nhưng nội dung mô tả sự cố nước rò rỉ thuộc Facilities), Rule Engine tự động phát hiện, hiệu chỉnh danh mục và cập nhật bất đồng bộ xuống cơ sở dữ liệu.
3.  **Layer 3: RAG Retrieval qua pgvector**:
    *   Sử dụng thư viện `pgvector` thực hiện tìm kiếm độ tương đồng Cosine (`1 - (embedding <=> ?)`) trên PostgreSQL đối với bảng `sample_tickets` và `sub_departments`.
    *   **RAG Short-circuit**: Nếu tìm thấy Ticket mẫu có độ tương đồng vượt ngưỡng quy định (ví dụ $\ge 0.5$), hệ thống tái sử dụng kết quả phân tích cũ và kích hoạt Agent AI phụ trách xác định hành động tiếp theo (`DetermineNextAction`) để bỏ qua bước gọi LLM chính, giúp tăng tốc độ xử lý.
    *   **RAG Context**: Nếu độ tương đồng ở mức trung bình, hệ thống sẽ trích xuất mô tả của phòng ban và các ticket mẫu liên quan để làm dữ liệu ngữ cảnh (Context) bổ trợ đính kèm vào Prompt gửi tới LLM.
4.  **Layer 4: AI Classification & Chuỗi Fallback dự phòng**:
    *   **Ollama (Mặc định)**: Gửi prompt đã làm giàu bằng ngữ cảnh RAG tới Ollama chạy cục bộ (mô hình `Qwen2.5`) yêu cầu trả về cấu trúc JSON nghiêm ngặt.
    *   **Chuỗi dự phòng (Fallback Chain)**: Nếu Ollama gặp sự cố, bị timeout hoặc kết quả trả về có độ tin cậy thấp (Confidence Score $< 0.5$), hệ thống tự động kích hoạt chuỗi dự phòng tuần tự: gọi Cloud AI thông qua **Groq (llama3)** $\rightarrow$ **Gemini (gemini-1.5-flash)**.
    *   **Dự phòng Heuristics cuối cùng (Safe Heuristic Fallback)**: Nếu toàn bộ kết nối AI thất bại, hệ thống tự tính toán rủi ro SLA dựa trên thời gian còn lại (dưới 4 tiếng $\rightarrow$ Rủi ro Cao, dưới 24 tiếng $\rightarrow$ Trung bình, còn lại $\rightarrow$ Thấp) và gán các giá trị an toàn tương ứng.
5.  **Layer 5: Persist & Action**:
    *   Lưu kết quả phân loại cuối cùng vào cơ sở dữ liệu.
    *   Trả về phản hồi DTO cho client.

### Xử lý Triage Hàng loạt (Batch AI Triage)
*   Cho phép gửi danh sách nhiều ID Ticket để chạy phân tích AI đồng thời thông qua Worker Pool.
*   Áp dụng chiến lược **Thành công một phần (Partial Success)**: Ticket nào không hợp lệ (đã quá hạn, đã đóng hoặc vi phạm Content Safety) sẽ được ghi nhận vào danh sách lỗi cá nhân, tránh làm ảnh hưởng đến tiến trình phân loại của các Ticket hợp lệ khác trong lô.

### Ví dụ Minh họa: Sự khác biệt giữa Code truyền thống và AI

Hãy tưởng tượng một nhân viên gửi một ticket hỗ trợ IT với nội dung khá lộn xộn và đầy cảm xúc như sau:
*   **Tiêu đề**: *Lỗi ổ Z*
*   **Mô tả**: *"Thư mục chứa số liệu báo cáo tài chính trên ổ Z (Share Drive) treo loading không vào được. Chiều nay 2h sếp phải mang đi họp Hội đồng quản trị."*

#### Kịch bản 1: Hệ thống không dùng AI (Chỉ dùng Code logic/Từ khóa)
Hệ thống hoạt động dựa trên việc quét từ khóa tĩnh (keyword matching):
*   **Phân mục (Category)**: Hệ thống tìm thấy từ *"thư mục"* hoặc *"ổ Z"* $\rightarrow$ Map sang danh mục `IT`. Tuy nhiên, quản trị viên phải cấu hình thủ công rất nhiều từ khóa đồng nghĩa liên quan.
*   **Mức độ ưu tiên (Urgency)**: Do người dùng không chọn *"Khẩn cấp"* trong form đăng ký, và hệ thống không tìm thấy các từ khóa cứng như *"server down"*, *"hỏng mạng toàn công ty"*, nó sẽ tự động xếp ticket này ở mức: `normal` hoặc `low`. Ticket bị đẩy xuống cuối hàng đợi chờ nhân viên IT xử lý theo thứ tự.
*   **Hậu quả**: Ticket bị vi phạm SLA và ảnh hưởng nghiêm trọng đến cuộc họp, vì code truyền thống không thể phân tích ngữ nghĩa để hiểu được tầm quan trọng của cụm từ *"chiều nay 2h họp Hội đồng quản trị"*.

#### Kịch bản 2: Hệ thống dùng AI Triage (Dự án hiện tại)
Thay vì chỉ tìm kiếm từ khóa, AI phân tích toàn bộ ngữ nghĩa, ngữ cảnh của đoạn văn bản và đối chiếu với chính sách SLA:
*   **Category**: `IT` (Phát hiện chính xác liên quan đến hạ tầng mạng/share drive).
*   **Urgency Level**: `high` (AI nhận diện cụm từ *"họp Hội đồng quản trị chiều nay"* là yếu tố cực kỳ nhạy cảm và quan trọng về mặt thời gian).
*   **SLA Breach Risk**: `high` (Rủi ro vi phạm rất cao, do khoảng cách tới cuộc họp chỉ còn lại chưa đầy 2 tiếng).
*   **Reason Summary**: *"Người dùng không truy cập được ổ đĩa mạng chứa báo cáo tài chính quan trọng phục vụ họp HĐQT diễn ra vào chiều nay."*
*   **Recommended Next Action**: *"Ngay lập tức cử nhân viên hỗ trợ kiểm tra trạng thái ổ đĩa mạng Share Drive. Liên hệ trực tiếp với người dùng qua điện thoại để hỗ trợ trực tiếp."*

---

## 4. Bộ Lọc An Toàn Nội Dung (Content Safety Service)

Bảo vệ hệ thống khỏi các dữ liệu độc hại, rác hoặc spam đầu vào trước khi đưa dữ liệu vào các mô hình AI hoặc lưu trữ lâu dài.

*   **Chuẩn hóa văn bản (Preprocessing)**: Chuẩn hóa ký tự Unicode, loại bỏ các ký tự ẩn hoặc ký tự biến đổi nhằm vượt qua bộ lọc từ khóa thông thường (obfuscation normalization).
*   **Phát hiện từ thô tục & lăng mạ**: Dựa trên danh sách các mẫu quy tắc từ vựng (`safetyrule.Rules`) kiểm tra trên nhiều tầng đại diện văn bản (Raw, Unicode, Obfuscated, Normalized).
*   **Phát hiện văn bản vô nghĩa (Gibberish)**: Tích hợp giải thuật phân tích tần suất ký tự hoặc các từ vô nghĩa để loại trừ các chuỗi ký tự ngẫu nhiên (ví dụ: "asdfghjkl").
*   **Phòng chống Spam**:
    *   Giới hạn số lượng liên kết URL tối đa trong Ticket.
    *   Giới hạn số lượng địa chỉ Email tối đa.
    *   Phát hiện các cụm từ mang tính quảng cáo, tiếp thị độc hại.

---

## 5. Báo Cáo SLA Hàng Ngày & Gửi Email Tự Động (Cron Job & SMTP)

Hỗ trợ giám sát hiệu suất xử lý Ticket của các đội ngũ hỗ trợ hàng ngày.

*   **Lập lịch tự động (robfig/cron)**: Bộ lập lịch nền chạy định kỳ vào lúc **17:00 hàng ngày** (hoặc kích hoạt thủ công qua API / script).
*   **Tổng hợp số liệu (Daily SLA Aggregation)**:
    *   Thống kê số lượng Ticket mới phát sinh trong ngày.
    *   Thống kê số lượng Ticket đã giải quyết, đã hủy.
    *   Đếm số lượng Ticket đã quá hạn xử lý (Overdue).
    *   Đếm số Ticket vi phạm thời gian cam kết SLA (SLA Breach).
    *   Tính toán thời gian giải quyết trung bình (Average Resolution Time) dựa trên khoảng thời gian từ lúc tạo đến lúc giải quyết (`resolved_at - created_at`).
    *   Phân loại số lượng Ticket theo từng mức độ ưu tiên (`high`, `medium`, `low`).
*   **Gửi Email HTML tự động**: Renders dữ liệu tổng hợp vào giao diện HTML chuyên nghiệp (`daily_report.html`) và tự động gửi tới email của người quản lý (IT Manager) thông qua dịch vụ **SMTP** (hỗ trợ TLS/PlainAuth).

---

## 6. Hệ Thống Đánh Giá Chất Lượng AI (AI Quality Evaluation)

Hệ thống cho phép các quản trị viên đánh giá độ chính xác của mô hình AI khi có sự thay đổi về Prompt hoặc cấu hình mô hình.

*   **Ground-Truth Dataset**: Chạy kiểm thử trên tập dữ liệu trường hợp thử nghiệm (`ai_evaluation_cases`) được lưu trong cơ sở dữ liệu.
*   **Tham chiếu mốc thời gian**: Tự động đưa mốc thời gian tĩnh làm mốc đánh giá rủi ro vi phạm SLA (tránh việc thời gian trôi qua làm thay đổi kết quả rủi ro SLA khách quan của bộ testcase).
*   **Chỉ số đo lường hiệu suất (Metrics)**:
    *   **Độ chính xác (Accuracy Rate)**: Tỷ lệ phần trăm các trường hợp khớp hoàn toàn cả 3 tiêu chí (Phân mục, Mức độ ưu tiên, Rủi ro SLA) so với kết quả mong đợi.
    *   **Hiệu năng (Performance)**: Đo lường tổng thời gian chạy, thời gian trễ trung bình của mỗi Ticket (Average Latency) và thông lượng xử lý (Throughput - số lượng xử lý trên giây).
*   **Lịch sử đánh giá (Evaluation Runs)**: Mỗi lượt đánh giá được lưu lại thành một bản ghi `AIEvaluationRun` kèm thông tin phiên bản Prompt, cấu hình LLM, người thực hiện và dữ liệu chi tiết của từng testcase dưới dạng JSON để thuận tiện cho việc so sánh hồi quy (regression tracking).

---

## 7. Phân Quyền Người Dùng (Keycloak OIDC Integration)

Hệ thống bảo vệ các tài nguyên API thông qua cơ chế phân quyền dựa trên vai trò (**Role-Based Access Control - RBAC**) tích hợp cùng máy chủ Keycloak.

*   **Xác thực JWT**: Middleware chặn các yêu cầu và giải mã chữ ký số của mã thông báo (JWT Bearer Token) được cấp bởi Keycloak.
*   **Các Vai trò trong Hệ thống**:
    *   **Requestor (Người yêu cầu)**: Chỉ được phép tạo Ticket và xem danh sách/chi tiết các Ticket do chính mình tạo ra.
    *   **Agent (Nhân viên hỗ trợ)**: Được xem danh sách tất cả các Ticket, cập nhật trạng thái xử lý, thực hiện nhập dữ liệu hàng loạt (Batch Import) và kích hoạt AI Triage cho từng Ticket đơn lẻ.
    *   **Manager (Người quản lý)**: Sở hữu toàn quyền kiểm soát hệ thống, bao gồm xem báo cáo SLA hàng ngày, tải nhật ký lỗi import, chạy phân loại AI hàng loạt (Batch Triage) và thực hiện các đợt đánh giá chất lượng AI.

---

## 8. Giám Sát & Ghi Nhật Ký Tập Trung (PLG Stack)

*   **Log cấu trúc (Structured Logging)**: Sử dụng thư viện `log/slog` của Go để ghi log dưới dạng JSON hoặc văn bản cấu trúc, đính kèm thông tin hữu ích như `request_id` (được sinh tự động trên mỗi request của Middleware), ID của Ticket và lý do nếu xảy ra lỗi.
*   **Promtail & Grafana Loki**: Các container ứng dụng xuất log ra một ổ đĩa chung (Shared Volume) giúp Promtail thu thập log bất đồng bộ, đẩy về Loki và hiển thị trực quan thông qua Grafana Dashboard mà không làm ảnh hưởng đến hiệu năng hay bảo mật của hệ thống chính.

---

## 9. Cơ Cấu Schema Cơ Sở Dữ Liệu RAG & Triage

*   `departments` / `sub_departments`: Lưu trữ cấu trúc tổ chức phòng ban. `sub_departments` chứa trường `embedding` kiểu `vector` (phục vụ RAG).
*   `rule_patterns`: Lưu trữ các mẫu quy tắc từ khóa/regex để định tuyến nhanh.
*   `sample_tickets`: Chứa các Ticket mẫu chuẩn, đi kèm trường `embedding` kiểu `vector` và các phân loại mẫu để hệ thống thực hiện so sánh RAG.
*   `tickets` / `ticket_events`: Bảng lưu trữ nghiệp vụ chính.
*   `ai_ticket_triage_results`: Lưu trữ lịch sử tất cả các kết quả phân tích AI trên mỗi Ticket.
*   `ai_evaluation_cases` / `ai_evaluation_runs`: Phục vụ cho tính năng Đánh giá Chất lượng AI.
*   `daily_ticket_reports`: Lưu các bản ghi báo cáo SLA đã tổng hợp hàng ngày.
