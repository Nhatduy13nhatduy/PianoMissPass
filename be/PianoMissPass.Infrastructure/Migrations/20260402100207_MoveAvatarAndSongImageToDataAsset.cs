using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class MoveAvatarAndSongImageToDataAsset : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<int>(
                name: "SheetId",
                table: "DataAsset",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddColumn<int>(
                name: "SongId",
                table: "DataAsset",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "UserId",
                table: "DataAsset",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_DataAsset_SongId",
                table: "DataAsset",
                column: "SongId");

            migrationBuilder.CreateIndex(
                name: "IX_DataAsset_UserId",
                table: "DataAsset",
                column: "UserId");

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

            migrationBuilder.Sql(
                """
                INSERT INTO "DataAsset" ("UserId", "AssetType", "Url", "DisplayOrder")
                SELECT "Id", 'image.avatar', "AvatarUrl", 1
                FROM "User"
                WHERE "AvatarUrl" IS NOT NULL AND btrim("AvatarUrl") <> '';
                """);

            migrationBuilder.Sql(
                """
                INSERT INTO "DataAsset" ("SongId", "AssetType", "Url", "DisplayOrder")
                SELECT "Id", 'image.song-cover', "ImageUrl", 1
                FROM "Song"
                WHERE "ImageUrl" IS NOT NULL AND btrim("ImageUrl") <> '';
                """);

            migrationBuilder.DropColumn(
                name: "AvatarUrl",
                table: "User");

            migrationBuilder.DropColumn(
                name: "ImageUrl",
                table: "Song");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AvatarUrl",
                table: "User",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ImageUrl",
                table: "Song",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE "User" u
                SET "AvatarUrl" = da."Url"
                FROM (
                    SELECT DISTINCT ON ("UserId") "UserId", "Url"
                    FROM "DataAsset"
                    WHERE "UserId" IS NOT NULL AND "AssetType" = 'image.avatar'
                    ORDER BY "UserId", "Id" DESC
                ) da
                WHERE u."Id" = da."UserId";
                """);

            migrationBuilder.Sql(
                """
                UPDATE "Song" s
                SET "ImageUrl" = da."Url"
                FROM (
                    SELECT DISTINCT ON ("SongId") "SongId", "Url"
                    FROM "DataAsset"
                    WHERE "SongId" IS NOT NULL AND "AssetType" = 'image.song-cover'
                    ORDER BY "SongId", "Id" DESC
                ) da
                WHERE s."Id" = da."SongId";
                """);

            migrationBuilder.DropForeignKey(
                name: "FK_DataAsset_Song_SongId",
                table: "DataAsset");

            migrationBuilder.DropForeignKey(
                name: "FK_DataAsset_User_UserId",
                table: "DataAsset");

            migrationBuilder.DropIndex(
                name: "IX_DataAsset_SongId",
                table: "DataAsset");

            migrationBuilder.DropIndex(
                name: "IX_DataAsset_UserId",
                table: "DataAsset");

            migrationBuilder.DropColumn(
                name: "SongId",
                table: "DataAsset");

            migrationBuilder.DropColumn(
                name: "UserId",
                table: "DataAsset");

            migrationBuilder.AlterColumn<int>(
                name: "SheetId",
                table: "DataAsset",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);
        }
    }
}
