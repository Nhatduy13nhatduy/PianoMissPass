using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddSongImageAndSheetHandsData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageUrl",
                table: "Song",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LeftData",
                table: "Sheet",
                type: "character varying(4000)",
                maxLength: 4000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RightData",
                table: "Sheet",
                type: "character varying(4000)",
                maxLength: 4000,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageUrl",
                table: "Song");

            migrationBuilder.DropColumn(
                name: "LeftData",
                table: "Sheet");

            migrationBuilder.DropColumn(
                name: "RightData",
                table: "Sheet");
        }
    }
}
