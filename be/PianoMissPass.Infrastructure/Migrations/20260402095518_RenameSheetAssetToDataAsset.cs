using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class RenameSheetAssetToDataAsset : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SheetAsset_Sheet_SheetId",
                table: "SheetAsset");

            migrationBuilder.DropPrimaryKey(
                name: "PK_SheetAsset",
                table: "SheetAsset");

            migrationBuilder.RenameTable(
                name: "SheetAsset",
                newName: "DataAsset");

            migrationBuilder.RenameIndex(
                name: "IX_SheetAsset_SheetId",
                table: "DataAsset",
                newName: "IX_DataAsset_SheetId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_DataAsset",
                table: "DataAsset",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DataAsset_Sheet_SheetId",
                table: "DataAsset",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DataAsset_Sheet_SheetId",
                table: "DataAsset");

            migrationBuilder.DropPrimaryKey(
                name: "PK_DataAsset",
                table: "DataAsset");

            migrationBuilder.RenameTable(
                name: "DataAsset",
                newName: "SheetAsset");

            migrationBuilder.RenameIndex(
                name: "IX_DataAsset_SheetId",
                table: "SheetAsset",
                newName: "IX_SheetAsset_SheetId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_SheetAsset",
                table: "SheetAsset",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_SheetAsset_Sheet_SheetId",
                table: "SheetAsset",
                column: "SheetId",
                principalTable: "Sheet",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
