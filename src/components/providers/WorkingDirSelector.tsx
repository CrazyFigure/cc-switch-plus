import { Folder, FolderSearch, X } from "lucide-react";
import { useTranslation } from "react-i18next";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface WorkingDirSelectorProps {
  value?: string;
  onBrowse: () => Promise<void>;
  onClear: () => void;
  className?: string;
}

// 工作目录选择器组件
export function WorkingDirSelector({
  value,
  onBrowse,
  onClear,
  className,
}: WorkingDirSelectorProps) {
  const { t } = useTranslation();

  // 显示路径的最后部分
  const displayPath = value
    ? value.split(/[/\\]/).pop() || value
    : t("workingDir.notSet");

  return (
    <div
      className={cn(
        "flex items-center gap-2 px-3 py-1.5 bg-muted/50 rounded-lg border border-border",
        className
      )}
      style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
    >
      <Folder className="w-4 h-4 text-muted-foreground flex-shrink-0" />
      <span
        className={cn(
          "text-sm truncate max-w-[180px]",
          !value && "text-muted-foreground italic"
        )}
        title={value || undefined}
      >
        {displayPath}
      </span>
      <Button
        size="icon"
        variant="ghost"
        onClick={onBrowse}
        className="h-6 w-6"
        title={t("workingDir.browse")}
      >
        <FolderSearch className="w-3.5 h-3.5" />
      </Button>
      {value && (
        <Button
          size="icon"
          variant="ghost"
          onClick={onClear}
          className="h-6 w-6"
          title={t("workingDir.clear")}
        >
          <X className="w-3.5 h-3.5" />
        </Button>
      )}
    </div>
  );
}
