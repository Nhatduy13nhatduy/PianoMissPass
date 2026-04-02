using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class ConvertAllIdsToString : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_Sheet_SheetId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_Song_SongId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_User_UserId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_EmailVerificationCode_User_UserId", table: "EmailVerificationCode");
            migrationBuilder.DropForeignKey(name: "FK_GenreSong_Genre_GenreId", table: "GenreSong");
            migrationBuilder.DropForeignKey(name: "FK_GenreSong_Song_SongId", table: "GenreSong");
            migrationBuilder.DropForeignKey(name: "FK_PasswordResetCode_User_UserId", table: "PasswordResetCode");
            migrationBuilder.DropForeignKey(name: "FK_Playlist_User_UserId", table: "Playlist");
            migrationBuilder.DropForeignKey(name: "FK_PlaylistSong_Playlist_PlaylistId", table: "PlaylistSong");
            migrationBuilder.DropForeignKey(name: "FK_PlaylistSong_Song_SongId", table: "PlaylistSong");
            migrationBuilder.DropForeignKey(name: "FK_RefreshToken_User_UserId", table: "RefreshToken");
            migrationBuilder.DropForeignKey(name: "FK_Sheet_Instrument_InstrumentId", table: "Sheet");
            migrationBuilder.DropForeignKey(name: "FK_Sheet_Song_SongId", table: "Sheet");
            migrationBuilder.DropForeignKey(name: "FK_Song_User_ArtistId", table: "Song");
            migrationBuilder.DropForeignKey(name: "FK_UserFavoriteSong_Song_SongId", table: "UserFavoriteSong");
            migrationBuilder.DropForeignKey(name: "FK_UserFavoriteSong_User_UserId", table: "UserFavoriteSong");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetLike_Sheet_SheetId", table: "UserSheetLike");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetLike_User_UserId", table: "UserSheetLike");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetPoint_Sheet_SheetId", table: "UserSheetPoint");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetPoint_User_PlayerId", table: "UserSheetPoint");

            migrationBuilder.Sql("ALTER TABLE \"User\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"EmailVerificationCode\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"PasswordResetCode\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"RefreshToken\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Song\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Sheet\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"DataAsset\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Instrument\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"UserSheetPoint\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Genre\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Playlist\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");

            migrationBuilder.AlterColumn<string>(
                name: "SheetId",
                table: "UserSheetPoint",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "PlayerId",
                table: "UserSheetPoint",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "UserSheetPoint",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "SheetId",
                table: "UserSheetLike",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "UserSheetLike",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "SongId",
                table: "UserFavoriteSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "UserFavoriteSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "User",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "ArtistId",
                table: "Song",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "Song",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "SongId",
                table: "Sheet",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "InstrumentId",
                table: "Sheet",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "Sheet",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "RefreshToken",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "RefreshToken",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "SongId",
                table: "PlaylistSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "PlaylistId",
                table: "PlaylistSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "Playlist",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "Playlist",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "PasswordResetCode",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "PasswordResetCode",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "Instrument",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "SongId",
                table: "GenreSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "GenreId",
                table: "GenreSong",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "Genre",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "EmailVerificationCode",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "EmailVerificationCode",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<string>(
                name: "UserId",
                table: "DataAsset",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "SongId",
                table: "DataAsset",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "SheetId",
                table: "DataAsset",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "DataAsset",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_Sheet_SheetId",
                table: "DataAsset",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_Song_SongId",
                table: "DataAsset",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_User_UserId",
                table: "DataAsset",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_EmailVerificationCode_User_UserId",
                table: "EmailVerificationCode",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_GenreSong_Genre_GenreId",
                table: "GenreSong",
                column: "GenreId",
                principalTable: "Genre",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_GenreSong_Song_SongId",
                table: "GenreSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PasswordResetCode_User_UserId",
                table: "PasswordResetCode",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Playlist_User_UserId",
                table: "Playlist",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistSong_Playlist_PlaylistId",
                table: "PlaylistSong",
                column: "PlaylistId",
                principalTable: "Playlist",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistSong_Song_SongId",
                table: "PlaylistSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_RefreshToken_User_UserId",
                table: "RefreshToken",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Sheet_Instrument_InstrumentId",
                table: "Sheet",
                column: "InstrumentId",
                principalTable: "Instrument",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Sheet_Song_SongId",
                table: "Sheet",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Song_User_ArtistId",
                table: "Song",
                column: "ArtistId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_UserFavoriteSong_Song_SongId",
                table: "UserFavoriteSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserFavoriteSong_User_UserId",
                table: "UserFavoriteSong",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetLike_Sheet_SheetId",
                table: "UserSheetLike",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetLike_User_UserId",
                table: "UserSheetLike",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetPoint_Sheet_SheetId",
                table: "UserSheetPoint",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetPoint_User_PlayerId",
                table: "UserSheetPoint",
                column: "PlayerId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_Sheet_SheetId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_Song_SongId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_DataAsset_User_UserId", table: "DataAsset");
            migrationBuilder.DropForeignKey(name: "FK_EmailVerificationCode_User_UserId", table: "EmailVerificationCode");
            migrationBuilder.DropForeignKey(name: "FK_GenreSong_Genre_GenreId", table: "GenreSong");
            migrationBuilder.DropForeignKey(name: "FK_GenreSong_Song_SongId", table: "GenreSong");
            migrationBuilder.DropForeignKey(name: "FK_PasswordResetCode_User_UserId", table: "PasswordResetCode");
            migrationBuilder.DropForeignKey(name: "FK_Playlist_User_UserId", table: "Playlist");
            migrationBuilder.DropForeignKey(name: "FK_PlaylistSong_Playlist_PlaylistId", table: "PlaylistSong");
            migrationBuilder.DropForeignKey(name: "FK_PlaylistSong_Song_SongId", table: "PlaylistSong");
            migrationBuilder.DropForeignKey(name: "FK_RefreshToken_User_UserId", table: "RefreshToken");
            migrationBuilder.DropForeignKey(name: "FK_Sheet_Instrument_InstrumentId", table: "Sheet");
            migrationBuilder.DropForeignKey(name: "FK_Sheet_Song_SongId", table: "Sheet");
            migrationBuilder.DropForeignKey(name: "FK_Song_User_ArtistId", table: "Song");
            migrationBuilder.DropForeignKey(name: "FK_UserFavoriteSong_Song_SongId", table: "UserFavoriteSong");
            migrationBuilder.DropForeignKey(name: "FK_UserFavoriteSong_User_UserId", table: "UserFavoriteSong");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetLike_Sheet_SheetId", table: "UserSheetLike");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetLike_User_UserId", table: "UserSheetLike");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetPoint_Sheet_SheetId", table: "UserSheetPoint");
            migrationBuilder.DropForeignKey(name: "FK_UserSheetPoint_User_PlayerId", table: "UserSheetPoint");

            migrationBuilder.AlterColumn<int>(
                name: "SheetId",
                table: "UserSheetPoint",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "PlayerId",
                table: "UserSheetPoint",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "UserSheetPoint",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "SheetId",
                table: "UserSheetLike",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "UserSheetLike",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "SongId",
                table: "UserFavoriteSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "UserFavoriteSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "User",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "ArtistId",
                table: "Song",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Song",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "SongId",
                table: "Sheet",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "InstrumentId",
                table: "Sheet",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Sheet",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "RefreshToken",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "RefreshToken",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "SongId",
                table: "PlaylistSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "PlaylistId",
                table: "PlaylistSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "Playlist",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Playlist",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "PasswordResetCode",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "PasswordResetCode",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Instrument",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "SongId",
                table: "GenreSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "GenreId",
                table: "GenreSong",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Genre",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "EmailVerificationCode",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "EmailVerificationCode",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "UserId",
                table: "DataAsset",
                type: "integer",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32,
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "SongId",
                table: "DataAsset",
                type: "integer",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32,
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "SheetId",
                table: "DataAsset",
                type: "integer",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32,
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "DataAsset",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(32)",
                oldMaxLength: 32)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_Sheet_SheetId",
                table: "DataAsset",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_Song_SongId",
                table: "DataAsset",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_User_UserId",
                table: "DataAsset",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_EmailVerificationCode_User_UserId",
                table: "EmailVerificationCode",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_GenreSong_Genre_GenreId",
                table: "GenreSong",
                column: "GenreId",
                principalTable: "Genre",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_GenreSong_Song_SongId",
                table: "GenreSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PasswordResetCode_User_UserId",
                table: "PasswordResetCode",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Playlist_User_UserId",
                table: "Playlist",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistSong_Playlist_PlaylistId",
                table: "PlaylistSong",
                column: "PlaylistId",
                principalTable: "Playlist",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistSong_Song_SongId",
                table: "PlaylistSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_RefreshToken_User_UserId",
                table: "RefreshToken",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Sheet_Instrument_InstrumentId",
                table: "Sheet",
                column: "InstrumentId",
                principalTable: "Instrument",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Sheet_Song_SongId",
                table: "Sheet",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Song_User_ArtistId",
                table: "Song",
                column: "ArtistId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_UserFavoriteSong_Song_SongId",
                table: "UserFavoriteSong",
                column: "SongId",
                principalTable: "Song",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserFavoriteSong_User_UserId",
                table: "UserFavoriteSong",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetLike_Sheet_SheetId",
                table: "UserSheetLike",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetLike_User_UserId",
                table: "UserSheetLike",
                column: "UserId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetPoint_Sheet_SheetId",
                table: "UserSheetPoint",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserSheetPoint_User_PlayerId",
                table: "UserSheetPoint",
                column: "PlayerId",
                principalTable: "User",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
