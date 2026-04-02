using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class SecureVerificationCodeStorage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_EmailVerificationCode_UserId_Code",
                table: "EmailVerificationCode");

            migrationBuilder.DropColumn(
                name: "Code",
                table: "EmailVerificationCode");

            migrationBuilder.AddColumn<string>(
                name: "CodeHash",
                table: "EmailVerificationCode",
                type: "character varying(128)",
                maxLength: 128,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "CodeSalt",
                table: "EmailVerificationCode",
                type: "character varying(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationCode_UserId",
                table: "EmailVerificationCode",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_EmailVerificationCode_UserId",
                table: "EmailVerificationCode");

            migrationBuilder.DropColumn(
                name: "CodeHash",
                table: "EmailVerificationCode");

            migrationBuilder.DropColumn(
                name: "CodeSalt",
                table: "EmailVerificationCode");

            migrationBuilder.AddColumn<string>(
                name: "Code",
                table: "EmailVerificationCode",
                type: "character varying(6)",
                maxLength: 6,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationCode_UserId_Code",
                table: "EmailVerificationCode",
                columns: new[] { "UserId", "Code" });
        }
    }
}
