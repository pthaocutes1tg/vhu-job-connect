# VHU Job Connect — mã nguồn MVP

Nền tảng kết nối sinh viên Văn Hiến với doanh nghiệp, cửa hàng và cá nhân tuyển dụng.

## Những phần đã có trong bộ mã nguồn
- React + Vite, giao diện responsive theo tông xanh dương – vàng.
- Đăng ký/đăng nhập bằng email và mật khẩu qua Supabase Auth.
- Phân vai sinh viên, nhà tuyển dụng và quản trị viên.
- Hồ sơ sinh viên: thông tin học tập, kỹ năng, kinh nghiệm, portfolio và ảnh đại diện.
- Hồ sơ nhà tuyển dụng: doanh nghiệp/cửa hàng/cá nhân, thông tin liên hệ và trạng thái xác minh.
- Đăng tin việc làm; tin mới ở trạng thái chờ duyệt.
- Tìm kiếm, lọc theo hình thức việc làm, xem chi tiết và ứng tuyển kèm thư giới thiệu.
- Sinh viên theo dõi đơn ứng tuyển; nhà tuyển dụng xem đơn và cập nhật trạng thái.
- Admin duyệt/từ chối tin và xác minh nhà tuyển dụng.
- SQL schema, RLS và trigger cơ bản ngăn tài khoản thường tự nâng quyền, tự xác minh hoặc tự xuất bản tin.

## Công nghệ
- Frontend: React 18, Vite, lucide-react.
- Backend: Supabase Auth, PostgreSQL, Storage, Row Level Security.
- Hosting đề xuất: Vercel hoặc Netlify.

## Cài đặt local
Yêu cầu Node.js 20+ và npm.

1. Tạo project tại https://supabase.com/dashboard.
2. Mở SQL Editor của project, chạy toàn bộ `supabase/schema.sql`.
3. Trong Authentication, bật Email provider; cấu hình Site URL và Redirect URLs theo địa chỉ local/deploy.
4. Sao chép `.env.example` thành `.env`.
5. Điền `VITE_SUPABASE_URL` và `VITE_SUPABASE_ANON_KEY` (publishable key hoặc anon key).
6. Chạy:
   ```bash
   npm install
   npm run dev
   ```
7. Kiểm tra bản build:
   ```bash
   npm run build
   ```

## Tạo tài khoản quản trị đầu tiên
1. Đăng ký tài khoản bình thường trên website.
2. Trong Supabase Dashboard > Authentication > Users, sao chép UUID của tài khoản đó.
3. Trong SQL Editor, chạy lệnh thay UUID thật:
   ```sql
   update public.profiles
   set role = 'admin'
   where id = 'UUID_TAI_KHOAN_CUA_BAN';
   ```
4. Đăng xuất và đăng nhập lại để tải vai trò quản trị.

Không cấp quyền admin cho tài khoản không được ủy quyền. Không đưa service_role key vào frontend, Git hoặc gửi qua tin nhắn.

## Triển khai lên Vercel
1. Đưa thư mục mã nguồn lên repository Git riêng tư của bạn.
2. Tạo project mới trên Vercel và import repository.
3. Framework preset: Vite; Build command: `npm run build`; Output directory: `dist`.
4. Thêm hai Environment Variables tương tự `.env` vào Vercel.
5. Deploy, sau đó thêm domain Vercel vào Supabase Authentication > URL Configuration > Redirect URLs.

## Những việc cần làm trước khi mở công khai
Đây là MVP để cấu hình và thử nghiệm, chưa phải dịch vụ production đã được kiểm thử độc lập. Trước khi nhận dữ liệu thật cần:
- Rà soát bảo mật RLS, SQL triggers và quyền truy cập hồ sơ ứng viên bởi người có chuyên môn.
- Tách dữ liệu hồ sơ công khai và dữ liệu liên hệ riêng tư; hiện cần hoàn thiện chính sách hiển thị hồ sơ ứng viên cho nhà tuyển dụng đã xác minh.
- Bổ sung upload CV có kiểm soát quyền truy cập, thông báo email, nhắn tin, lịch phỏng vấn và chức năng báo cáo tin xấu.
- Bổ sung CAPTCHA/rate limiting, chống spam, audit log, backup/khôi phục và giám sát lỗi.
- Hoàn thiện quy trình xác minh doanh nghiệp/cửa hàng/cá nhân ngoài đời thực.
- Viết điều khoản sử dụng, chính sách quyền riêng tư, quy trình xử lý dữ liệu cá nhân và đầu mối tiếp nhận khiếu nại.
- Kiểm thử trên điện thoại, trình duyệt phổ biến, kiểm thử tải và kiểm thử bảo mật trước khi công bố rộng rãi.

## Giới hạn triển khai
Tôi đã chuẩn bị mã nguồn và hướng dẫn, nhưng không thể tạo project Supabase/Vercel thay bạn nếu chưa có thao tác đăng nhập và cấp quyền từ chính tài khoản của bạn. Không gửi mật khẩu, mã OTP hoặc service_role key trong cuộc trò chuyện. Bạn chỉ cần tự tạo project và cung cấp các thông tin công khai cần thiết theo hướng dẫn; publishable/anon key được thiết kế để dùng ở frontend nhưng vẫn phải đi kèm RLS đúng.

## Nhật ký sửa lỗi (06/11/2026)
- `src/App.jsx`: sửa lỗi biến `cover_note` chưa khai báo trong hàm ứng tuyển (trước đây bấm "Gửi đơn ứng tuyển" sẽ lỗi).
- `supabase/schema.sql`: đổi tên hàm `public.current_role()` thành `public.my_role()` vì `current_role` là từ khóa dành riêng của PostgreSQL (schema cũ không chạy được).
- `supabase/schema.sql`: nhà tuyển dụng được phép tự đóng (`closed`) tin của mình; duyệt/từ chối vẫn chỉ admin.
- Thêm `.gitignore` để không đưa `.env`, `node_modules`, `dist` lên Git.
- Đã kiểm chứng `npm install` và `npm run build` chạy thành công với Node 22.

- Sửa thêm (lần 2): thêm khóa ngoại `jobs.employer_id → employer_profiles.user_id` ở cuối `supabase/schema.sql`, để truy vấn `jobs` kèm `employer_profiles(...)` hoạt động (trước đó danh sách việc làm luôn trống). Đã chạy thử schema + luồng đăng tin/duyệt/ứng tuyển trên Postgres 16.
