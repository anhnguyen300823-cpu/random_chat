-- Bảng Profiles
CREATE TABLE profiles (
  id UUID REFERENCES auth.users NOT NULL PRIMARY KEY,
  nickname TEXT,
  avatar_url TEXT,
  gender TEXT,
  age INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Bật RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Cho phép tất cả mọi người được đọc profile
CREATE POLICY "Public profiles are viewable by everyone."
  ON profiles FOR SELECT
  USING ( true );

-- Chỉ cho phép người dùng tự insert bản ghi profile của mình
CREATE POLICY "Users can insert their own profile."
  ON profiles FOR INSERT
  WITH CHECK ( auth.uid() = id );

-- Chỉ cho phép người dùng tự update profile của mình
CREATE POLICY "Users can update own profile."
  ON profiles FOR UPDATE
  USING ( auth.uid() = id );

-- Tạo Storage Buckets
insert into storage.buckets (id, name, public) values ('images', 'images', true);
insert into storage.buckets (id, name, public) values ('voices', 'voices', true);

-- Policy cho bucket images (Ai cũng được xem, chỉ người dùng đăng nhập được phép upload)
CREATE POLICY "Images are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'images');
CREATE POLICY "Users can upload images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'images' AND auth.role() = 'authenticated');

-- Policy cho bucket voices
CREATE POLICY "Voices are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'voices');
CREATE POLICY "Users can upload voices" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'voices' AND auth.role() = 'authenticated');
