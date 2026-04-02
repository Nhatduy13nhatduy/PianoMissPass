using Microsoft.EntityFrameworkCore;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<EmailVerificationCode> EmailVerificationCodes => Set<EmailVerificationCode>();
    public DbSet<PasswordResetCode> PasswordResetCodes => Set<PasswordResetCode>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Song> Songs => Set<Song>();
    public DbSet<Sheet> Sheets => Set<Sheet>();
    public DbSet<DataAsset> DataAssets => Set<DataAsset>();
    public DbSet<Instrument> Instruments => Set<Instrument>();
    public DbSet<UserSheetPoint> UserSheetPoints => Set<UserSheetPoint>();
    public DbSet<UserSheetLike> UserSheetLikes => Set<UserSheetLike>();
    public DbSet<Genre> Genres => Set<Genre>();
    public DbSet<GenreSong> GenreSongs => Set<GenreSong>();
    public DbSet<UserFavoriteSong> UserFavoriteSongs => Set<UserFavoriteSong>();
    public DbSet<Playlist> Playlists => Set<Playlist>();
    public DbSet<PlaylistSong> PlaylistSongs => Set<PlaylistSong>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("User");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserName).HasMaxLength(255).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(255).IsRequired();
            entity.Property(x => x.IsEmailVerified).HasDefaultValue(false);
            entity.Property(x => x.VerificationFailedAttempts).HasDefaultValue(0);
            entity.Property(x => x.Password).HasMaxLength(255).IsRequired();
            entity.Property(x => x.Role).HasConversion<string>().HasMaxLength(20).HasDefaultValue(UserRole.User);
            entity.HasIndex(x => x.Email).IsUnique();
        });

        modelBuilder.Entity<EmailVerificationCode>(entity =>
        {
            entity.ToTable("EmailVerificationCode");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.CodeHash).HasMaxLength(128).IsRequired();
            entity.Property(x => x.CodeSalt).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => x.UserId);

            entity.HasOne(x => x.User)
                .WithMany(x => x.EmailVerificationCodes)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

            modelBuilder.Entity<PasswordResetCode>(entity =>
            {
                entity.ToTable("PasswordResetCode");
                entity.HasKey(x => x.Id);
                entity.Property(x => x.CodeHash).HasMaxLength(128).IsRequired();
                entity.Property(x => x.CodeSalt).HasMaxLength(64).IsRequired();
                entity.Property(x => x.FailedAttempts).HasDefaultValue(0);
                entity.HasIndex(x => x.UserId);

                entity.HasOne(x => x.User)
                .WithMany(x => x.PasswordResetCodes)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("RefreshToken");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Token).HasMaxLength(512).IsRequired();
            entity.HasIndex(x => x.Token).IsUnique();

            entity.HasOne(x => x.User)
                .WithMany(x => x.RefreshTokens)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Song>(entity =>
        {
            entity.ToTable("Song");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(255).IsRequired();
            entity.Property(x => x.Composer).HasMaxLength(255);
            entity.Property(x => x.PlayCount).HasDefaultValue(0);

            entity.HasOne(x => x.Artist)
                .WithMany(x => x.Songs)
                .HasForeignKey(x => x.ArtistId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Sheet>(entity =>
        {
            entity.ToTable("Sheet");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(255).IsRequired();
            entity.Property(x => x.LeftData).HasMaxLength(4000);
            entity.Property(x => x.RightData).HasMaxLength(4000);
            entity.Property(x => x.LikeCount).HasDefaultValue(0);

            entity.HasOne(x => x.Song)
                .WithMany(x => x.Sheets)
                .HasForeignKey(x => x.SongId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Instrument)
                .WithMany(x => x.Sheets)
                .HasForeignKey(x => x.InstrumentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<DataAsset>(entity =>
        {
            entity.ToTable("DataAsset");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.AssetType)
                .HasConversion(
                    x => DataAssetTypeConverter.ToStorageValue(x),
                    x => DataAssetTypeConverter.FromStorageValue(x))
                .HasMaxLength(100)
                .IsRequired();
            entity.Property(x => x.Url).HasMaxLength(500).IsRequired();
            entity.Property(x => x.PublicId).HasMaxLength(255);
            entity.HasIndex(x => x.SheetId);
            entity.HasIndex(x => x.SongId);
            entity.HasIndex(x => x.UserId);

            entity.HasOne(x => x.Sheet)
                .WithMany(x => x.DataAssets)
                .HasForeignKey(x => x.SheetId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Song)
                .WithMany(x => x.DataAssets)
                .HasForeignKey(x => x.SongId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.User)
                .WithMany(x => x.DataAssets)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Instrument>(entity =>
        {
            entity.ToTable("Instrument");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(100).IsRequired();
        });

        modelBuilder.Entity<UserSheetPoint>(entity =>
        {
            entity.ToTable("UserSheetPoint");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.SheetId, x.PlayerId }).IsUnique();

            entity.HasOne(x => x.Sheet)
                .WithMany(x => x.UserSheetPoints)
                .HasForeignKey(x => x.SheetId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Player)
                .WithMany(x => x.SheetPoints)
                .HasForeignKey(x => x.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserSheetLike>(entity =>
        {
            entity.ToTable("UserSheetLike");
            entity.HasKey(x => new { x.UserId, x.SheetId });

            entity.HasOne(x => x.User)
                .WithMany(x => x.SheetLikes)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Sheet)
                .WithMany(x => x.UserSheetLikes)
                .HasForeignKey(x => x.SheetId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Genre>(entity =>
        {
            entity.ToTable("Genre");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(100).IsRequired();
        });

        modelBuilder.Entity<GenreSong>(entity =>
        {
            entity.ToTable("GenreSong");
            entity.HasKey(x => new { x.GenreId, x.SongId });

            entity.HasOne(x => x.Genre)
                .WithMany(x => x.GenreSongs)
                .HasForeignKey(x => x.GenreId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Song)
                .WithMany(x => x.GenreSongs)
                .HasForeignKey(x => x.SongId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserFavoriteSong>(entity =>
        {
            entity.ToTable("UserFavoriteSong");
            entity.HasKey(x => new { x.UserId, x.SongId });

            entity.HasOne(x => x.User)
                .WithMany(x => x.FavoriteSongs)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Song)
                .WithMany(x => x.FavoriteByUsers)
                .HasForeignKey(x => x.SongId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Playlist>(entity =>
        {
            entity.ToTable("Playlist");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(255).IsRequired();

            entity.HasOne(x => x.User)
                .WithMany(x => x.Playlists)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PlaylistSong>(entity =>
        {
            entity.ToTable("PlaylistSong");
            entity.HasKey(x => new { x.PlaylistId, x.SongId });
            entity.HasIndex(x => new { x.PlaylistId, x.DisplayOrder }).IsUnique();

            entity.HasOne(x => x.Playlist)
                .WithMany(x => x.PlaylistSongs)
                .HasForeignKey(x => x.PlaylistId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(x => x.Song)
                .WithMany(x => x.PlaylistSongs)
                .HasForeignKey(x => x.SongId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}

