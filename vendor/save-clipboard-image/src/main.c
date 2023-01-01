#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include "lodepng.h"

const char* help = (""
 "save-clipboard-image OUT_FILE\n"
 "  saves clipboard image to png file\n"
"");

int main(int argc, char *argv[])
{
  if(argc <= 1) {
    printf("Missed OUT_FILE\n");
    return 2;
  }
  else if(strcmp(argv[1], "--help") == 0) {
    printf(help);
    return 0;
  }
  else {
    OpenClipboard(NULL);
    int i = 0;
    int ret = 0;
    while((i = EnumClipboardFormats(i)) != 0) {
      if(i == CF_DIB) {
        break;
      }
    }
    if(i == CF_DIB) {
      BITMAPINFO *bitMap = (BITMAPINFO *)GetClipboardData(CF_DIB);
      BITMAPINFOHEADER header = bitMap->bmiHeader;
      //printf("%i x %i @ %i", header.biWidth, header.biHeight, header.biBitCount);
      //printf("%i %i", header.biSize, sizeof(BITMAPINFOHEADER));
      char *image = (char*)malloc(header.biWidth * header.biHeight * 3);
      for(int y = 0; y < header.biHeight; y += 1) {
        for(int x = 0; x < header.biWidth; x += 1) {
          //? why 3
          int srcPos = 3 + x + (header.biHeight - 1 - y) * header.biWidth;
          int destPos = 3 * (x + y * header.biWidth);
          image[destPos + 0] = bitMap->bmiColors[srcPos].rgbRed;
          image[destPos + 1] = bitMap->bmiColors[srcPos].rgbGreen;
          image[destPos + 2] = bitMap->bmiColors[srcPos].rgbBlue;
        }
      }
      lodepng_encode24_file(argv[1], (unsigned char*)image, header.biWidth, header.biHeight);
      free(image);
      
      if(0) {
        unsigned char* png;
        size_t pngsize;
    
        //freopen(NULL, "wb", stderr);
        unsigned error = lodepng_encode32(&png, &pngsize, (unsigned char*)bitMap->bmiColors, header.biWidth, header.biHeight);
        fwrite(png, pngsize, 1, stdout);
        free(png);
      }
      ret = 0;
    }
    else {
      ret = 1;
      printf("clipboard does not contains image");
    }
    CloseClipboard();
    return ret;
  }
}