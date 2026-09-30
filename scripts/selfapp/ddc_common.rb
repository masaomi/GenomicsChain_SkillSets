# frozen_string_literal: true

require 'digest'

# Shared by the self-application DDC harness and comparer (design §6.4–§6.5).
module DdcCommon
  # The checker packages the DDC compares, in load order.
  PACKAGES = %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3 genomicschain_prov].freeze

  module_function

  # Every regular file under dir (dot files included, symlinks not followed),
  # as {relative path => sha256}, sorted bytewise by path — the S−1 rule.
  def tree_files(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir)
       .select { |rel| File.file?(File.join(dir, rel)) && !File.symlink?(File.join(dir, rel)) }
       .sort_by(&:b)
       .to_h { |rel| [rel, Digest::SHA256.file(File.join(dir, rel)).hexdigest] }
  end

  # sha256 of the lines "<sha256>  <relative path>\n", as `sha256sum` prints them.
  def tree_sha256(files)
    Digest::SHA256.hexdigest(files.map { |rel, sha| "#{sha}  #{rel}\n" }.join)
  end

  # The checker packages under root, paths relative to root.
  def package_files(root)
    PACKAGES.select { |p| File.directory?(File.join(root, p)) }.flat_map do |pkg|
      tree_files(File.join(root, pkg)).map { |rel, sha| ["#{pkg}/#{rel}", sha] }
    end.sort_by { |rel, _| rel.b }.to_h
  end
end
